---
title: 'Connection pools sized'
type: 'chore'
ticket: '16'
created: '2026-10-08'
status: 'built'
baseline_revision: 'af237e89d44db446071249079f2e16c06edde397'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 1
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The `reading` role opens a second pool to the primary, so a web process may hold 2 × `RAILS_MAX_THREADS` primary connections, and nobody has counted what every pool of every process on a deploy destination can open against its one Postgres. With today's production `database.yml` (every pool 5) the staging destination's processes can open 85 connections, too close to Postgres' default `max_connections` of 100.

**Approach:** A `ConnectionBudget` object counts, for a deploy destination, the connections each process can open (pool size × the pools that process uses), per process and in total; production pools are sized explicitly so that total stays under a set limit while each pool still covers the threads that use it. A test fails when the committed configuration goes over the limit or undersizes a pool; a rake task prints the same figures on a host and compares them with the live `max_connections`. The figures are recorded in the epic Notes, and the author compares them on staging.

## Boundaries & Constraints

**Always:** Count from the committed configuration, never a hand-copied number: pool sizes from `ActiveRecord::Base.configurations.configs_for(env_name: "production", include_hidden: true)` (`max_connections`), Solid Queue processes from `config/queue.yml` / `config/queue_import.yml` / `config/recurring.yml` for `production`, roles and commands from `config/deploy.yml` merged with `config/deploy.<destination>.yml`. A pool is never smaller than the threads that lease from it: primary ≥ Puma's threads and ≥ every worker's `threads`; queue ≥ every worker's `threads` + 2 (Solid Queue's own estimate: polling thread and heartbeat). The limit leaves room for one-off sessions (console, a booting container's `db:prepare`, a backup).

**Never:** No change to the development or test pools (the `default` anchor keeps its fallback of 5). No change to Postgres' `max_connections` or the db accessory. No read replica. No pgbouncer. No planning ids in code, tests or config.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Committed staging config | `RAILS_MAX_THREADS`, `JOB_CONCURRENCY` unset (deploy sets neither) | web role: Puma 17 (primary 3 + reading 3 + queue 5 + cache 3 + cable 3), supervisor 5, dispatcher 5, scheduler 5, worker 14; import role: supervisor 5, worker 14; total 65 ≤ limit 80 | No error expected |
| Over the limit | A pool size or process count that pushes the total above 80 (e.g. `RAILS_MAX_THREADS=10`) | `over_limit?` true; the test names the total and the limit | Test fails; task exits non-zero |
| Undersized pool | queue pool < a worker's threads + 2, or primary < Puma's threads or a worker's threads | `undersized` lists each pool with what it needs | Test fails; task exits non-zero |
| More job processes | `JOB_CONCURRENCY=2` | two workers counted in the web role | No error expected while within the limit |
| Recurring skipped | the import role's `--skip-recurring`; a queue file with no dispatcher | no scheduler counted for that role; no dispatcher counted when the file has none | No error expected |
| Task with a database | `bin/rails "db:connection_budget[staging]"` on a host whose Postgres answers | prints each process with its pools, the total, the limit, and the live `max_connections` less `superuser_reserved_connections` | exits non-zero if the total exceeds the limit or the live allowance |
| Task without a database | Postgres unreachable | prints the computed figures and says the live value could not be read | exits on the limit check alone |

</intent-contract>

## Code Map

- `config/database.yml` -- `default` anchor: `max_connections: ENV.fetch("RAILS_MAX_THREADS") { 5 }` (leave it). `production:` has `primary` (anchor `primary_production`), `cache`, `queue`, `cable`, all inheriting 5. Set explicit production sizes here.
- `lib/application_record.rb` -- `connects_to database: { writing: :primary, reading: :primary }`: two pools on the primary per process; only `ApplicationRecord` switches role (`ApplicationController#read_only_unless_writing`), so Solid Queue, Cache and Cable never open a reading pool.
- `config/puma.rb` -- `threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)`; no `workers` call, but Puma 8 reads `WEB_CONCURRENCY` itself (`puma_options_from_env`): unset or blank → one Puma process, `N` → `N` worker processes (the cluster master loads no app and holds no connection); `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` forks a Solid Queue supervisor that forks the processes of `config/queue.yml`.
- `config/queue.yml` -- production: one dispatcher, one worker entry `threads: 3`, `processes: ENV.fetch("JOB_CONCURRENCY", 1)`. `config/queue_import.yml` -- one worker, `threads: 1`, `processes: 1`, no dispatcher key (Solid Queue then runs no dispatcher). `config/recurring.yml` -- production has tasks, so the web role's Solid Queue runs a scheduler.
- `config/deploy.yml` -- `env.clear` sets `SOLID_QUEUE_IN_PUMA: true`, `DB_HOST`; one `db` accessory (postgres:18) per destination. `config/deploy.staging.yml` -- roles `web` and `import` (`cmd: bin/jobs -c config/queue_import.yml --skip-recurring`). `config/deploy.production.yml` -- same roles, empty host lists.
- `test/config/queue_config_test.rb` -- reference for reading these YAML files with ERB in a test (`load_config`).
- `lib/` -- the `lib` package, autoloaded (`config.autoload_lib(ignore: %w[assets tasks])`); `lib/tasks/` holds only `.keep`. `test/support/rake_tasks.rb` -- `rake_task(name)` helper for task tests; a `.rake` file defines no constant.
- Solid Queue 1.7 (`SolidQueue::Configuration#estimated_database_pool_size_for_worker`): threads + 2.

## Tasks & Acceptance

**Execution:**
- [x] `lib/connection_budget.rb` -- new class `ConnectionBudget`. `new(destination:, root: Rails.root)`; `processes` returns one entry per process (`name`, its pools as `{ "primary" => n, "primary (reading)" => n, ... }`, `connections` = their sum); `total`; `LIMIT = 80` with one comment line (Postgres' default 100, less its 3 superuser slots and room for one-off sessions); `over_limit?`; `undersized` returns one message per pool smaller than its threads need. Which databases each process kind uses: Puma → primary writing + primary reading + queue + cache + cable; Solid Queue worker → primary + queue + cache + cable; supervisor, dispatcher, scheduler → queue. Roles: the web role runs one Puma process, plus, when the destination's env sets `SOLID_QUEUE_IN_PUMA`, a supervisor and the processes of `config/queue.yml`; a role whose `cmd` is `bin/jobs -c <file>` runs a supervisor and the processes of `<file>`, with no scheduler when the cmd has `--skip-recurring`. Workers count `processes` times; a scheduler counts when `config/recurring.yml` has production tasks and recurring is not skipped. Each role is counted under its deploy env: the `env.clear` of `config/deploy.yml`, then of `config/deploy.<destination>.yml`, then of the role, laid over the process `ENV` while that role's `database.yml` and queue files are evaluated (restore `ENV` afterwards, including keys that were absent); so `RAILS_MAX_THREADS`, `JOB_CONCURRENCY`, `WEB_CONCURRENCY` and `SOLID_QUEUE_IN_PUMA` set in a deploy file change the count, and pool sizes are per role. Puma threads come from that env's `RAILS_MAX_THREADS` (default 3, as `config/puma.rb` reads it); the web role counts `WEB_CONCURRENCY` Puma processes (one when unset or blank; a non-integer value such as `auto` raises with the role's name). -- one place that turns the committed configuration into the figures.
- [x] `config/database.yml` -- production: primary, cache and cable `max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 3 } %>`; queue 5 (a worker's 3 threads + 2). -- brings the staging total from 85 to 65 while every pool covers its threads.
- [x] `lib/tasks/db.rake` (or a name of the same intent) -- task `db:connection_budget[destination]` (default `staging`): prints each process and its pools, the total and the limit, then reads `SHOW max_connections` and `SHOW superuser_reserved_connections` through `ActiveRecord::Base.connection` when it can and prints the allowance; rescues `ActiveRecord::ConnectionNotEstablished` (and the adapter's connection errors) to say the live value is unknown; `abort`s when over the limit, undersized, or above the live allowance. -- what the author runs on staging (`kamal app exec -d staging "bin/rails 'db:connection_budget[staging]'"`).
- [x] `test/lib/connection_budget_test.rb` -- with `RAILS_MAX_THREADS` and `JOB_CONCURRENCY` removed from `ENV` for the test (restored after), as the deploy files set neither: staging's committed figures (each process and the total 65), not over the limit, nothing undersized; production destination likewise within the limit; `JOB_CONCURRENCY=2` counts a second worker; `RAILS_MAX_THREADS=10` goes over the limit; a temp copy of `config/deploy.yml` with `JOB_CONCURRENCY: 3` under `env.clear` gives 93 and is over the limit; one with `WEB_CONCURRENCY: 2` counts two Puma processes (82, over); an import role `env: clear: RAILS_MAX_THREADS: 8` reports its queue pool undersized; a queue file with a 4-thread worker against a queue pool of 5 is reported undersized (a temp `root` holding copied config files is acceptable for the synthetic cases). -- covers the matrix.
- [x] `test/lib/tasks/connection_budget_task_test.rb` (or beside the other task tests) -- the task prints the total and the limit and exits normally for staging; with the database reachable it prints the live allowance. -- covers the task rows.
- [x] `_bmad-output/initiative-gameble/epic-space-terminal-redesign/epic-space-terminal-redesign.md` -- append a Note with the computed figures (per process and the total against the limit) and that the author compares them with staging's `max_connections`. `_bmad-output/initiative-gameble/deferred-work.md` -- add a `resolved:` line under the reading-pool entry naming the budget, test and task.

**Acceptance Criteria:**
- Given the committed configuration, when `bin/rails test test/lib/connection_budget_test.rb` runs, then it passes and fails as soon as a change pushes staging's total above 80 or a pool below the threads that use it.
- Given a staging container, when the author runs `bin/rails "db:connection_budget[staging]"`, then it prints every process with its pools, the total, the limit and Postgres' live allowance, and exits non-zero if any check fails.
- Given the epic file, when the author reads its Notes, then the computed figures are there to compare with staging's `max_connections`.

## Implementation Notes

- Pool sizes are read with `ActiveRecord::DatabaseConfigurations.new(<root>/config/database.yml, ERB evaluated now).configs_for(env_name: "production", include_hidden: true)` rather than the boot-time `ActiveRecord::Base.configurations`, so `RAILS_MAX_THREADS` set by a test (or a temp `root`) is honoured; same API, same file.
- The deploy files are read without ERB (their only ERB is Kamal's build-time version, which runs git); the queue and recurring files with ERB, as Solid Queue reads them.
- The pool check is a superset of the plan's: every pool a process uses must cover its threads (Puma: all five; worker: primary, cache, cable ≥ threads, queue ≥ threads + 2). It therefore also reports the queue pool (fixed at 5) when `RAILS_MAX_THREADS` goes above 5.
- A role with several hosts counts one container per host (named `role (host)`); a role with no host yet counts one. A role `cmd` that is neither Puma nor `bin/jobs` raises instead of being skipped.

## Plan Change Log

- 2026-10-08, review pass 1: triggered by the deploy-env and `WEB_CONCURRENCY` findings (and the deploy-overlap wording). Amended the Code Map's Puma line, the `ConnectionBudget` and test tasks (count each role under its merged deploy env, count `WEB_CONCURRENCY` Puma processes, deploy-file test cases) and the Design Notes (Solid Queue connects at boot during a deploy; Action Cable and Solid Cache threads stated, not counted). Known-bad state avoided: a test that stays green when a deploy file sets `JOB_CONCURRENCY` or `WEB_CONCURRENCY` past the limit. KEEP: the `ConnectionBudget` shape (`processes` with `name`/`pools`/`connections`, `total`, `LIMIT`, `over_limit?`, `undersized` covering every pool a process uses), the fresh `ActiveRecord::DatabaseConfigurations` read of `<root>/config/database.yml`, the `db:connection_budget[destination]` task with its live allowance and unreachable branch, the `.dockerignore` change keeping `config/deploy*.yml` in the image with its guard test, one container per host, a raise on an unknown role `cmd`, the epic Note and the `deferred-work.md` resolved line.

- `.dockerignore` no longer excludes `config/deploy*.yml` (the Rails default did): without it the task cannot run in a staging container, which the second acceptance criterion requires. Guarded by a test in `test/lib/connection_budget_task_test.rb`.

## Review Triage Log

### 2026-10-08 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` The budget reads `RAILS_MAX_THREADS` and `JOB_CONCURRENCY` from the process `ENV`, not the deploy files' env, so uncommenting `JOB_CONCURRENCY: 3` in `config/deploy.yml` (93 connections) keeps the test green — the plan told the test to clear `ENV` instead of counting under the deploy env; amended the `ConnectionBudget` task (each role counted under its merged deploy env) and the test task (deploy-file cases).
  - `[medium]` `[bad_plan]` Puma's `WEB_CONCURRENCY` workers are never counted; Puma 8 reads it in `puma_options_from_env`, and `WEB_CONCURRENCY: 2` (already a commented knob in `config/deploy.yml`) makes 82 — the Code Map said the opposite; amended the Code Map, the `ConnectionBudget` task and the test task.
  - `[low]` `[reject]` Production primary of 3 is smaller than Puma's 3 threads plus Action Cable's 4 workers that run `connect`'s `Player.find_by` — real but each lease is one query, a full pool waits (5 s checkout timeout) rather than fails, the pool of 5 before was already short of 7, and sizing for it changes the contract's figures; stated in the epic Note through the amended Design Notes.
  - `[low]` `[reject]` Solid Cache's expiry thread leases from the cache pool beside Puma's threads — same reasoning: one short query, waits rather than fails; stated in the epic Note through the amended Design Notes.
  - `[low]` `[bad_plan]` The Note's "the new container opens its pools lazily" is wrong for Solid Queue, whose processes connect at boot — direct correction of the plan's Design Notes, which the Note follows; amended.

### 2026-10-08 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Puma's threads (`DEFAULT_PUMA_THREADS = 3`) and Solid Queue's worker default are copied numbers, so changing `config/puma.rb`'s default or adding a `threads`/`workers` call keeps the test green — `ConnectionBudget` now reads `:max_threads` and `:workers` from `Puma::Configuration` loaded from `config/puma.rb` under the role's env, and worker defaults from `SolidQueue::Configuration::WORKER_DEFAULTS`; tests cover a temp `puma.rb` with `threads 4, 4` and `workers 2`.
  - `[low]` `[reject]` The plan's "import role `RAILS_MAX_THREADS: 8` reports its queue pool undersized" case was replaced — the case cannot occur (the import worker's 1 thread needs 3 of its 5 queue connections); the undersized case is tested on the web role instead; the only fix would edit this build's plan.
  - `[low]` `[patch]` A role's env was laid over the live `ENV`, so a key set in the shell or the container running the task leaked into every role's count — `with_env` now removes the counted keys (`RAILS_MAX_THREADS`, `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, Puma's thread keys, the `SOLID_QUEUE_*` keys) before applying the role's merged deploy env, and restores them; a test sets them in `ENV` only and gets 65.

## Design Notes

Counting is by pool size, not by the threads that happen to hold connections: a pool opens connections lazily up to its size, so the size is the bound the configuration permits. The budget is per destination because every role of a destination talks to that destination's one db accessory. A Kamal deploy briefly runs the old and new container of a role side by side: the new container's Puma opens its pools lazily, but its Solid Queue processes connect as soon as they boot (a few connections each, not their full pools) beside its `db:prepare`; the room between the limit (80) and Postgres' 97 absorbs that overlap and nothing measures it, so the epic Note says so and asks the author to watch `pg_stat_activity` during a staging deploy. Two thread sources the count leaves out, also stated in the Note: Action Cable's worker pool (4 threads) runs `ApplicationCable::Connection#connect` on the writing pool beside Puma's threads, and Solid Cache's expiry thread leases from the cache pool; both hold a connection for a single query, so a full pool makes them wait, not fail, and sizing for them would move every figure of the matrix.

## Verification

**Commands:**
- `bin/rails test test/lib/connection_budget_test.rb test/config` -- expected: pass
- `bin/rails test` -- expected: 0 failures, 0 errors
- `RAILS_ENV=development bin/rails "db:connection_budget[staging]"` -- expected: prints the processes, total 65, limit 80, the local Postgres allowance; exit 0
- `bin/rubocop lib config test/lib` -- expected: no offenses
- `bin/rails zeitwerk:check` and `bundle exec packwerk check` -- expected: pass

## Auto Run Result

**Summary:** `ConnectionBudget` counts, per Kamal destination, the Postgres connections every process can open (pool size × the pools it uses), each role under its merged deploy env, from `config/database.yml`, `config/puma.rb` (through Puma's own configuration), the Solid Queue files and the deploy files. Production pools are sized (primary, cache, cable `RAILS_MAX_THREADS`, default 3; queue 5): staging goes from 85 to 65 against a limit of 80. A test fails above the limit or on a pool smaller than its threads; `bin/rails "db:connection_budget[staging]"` prints the figures and Postgres' live allowance.

**Files changed:**
- `lib/connection_budget.rb` -- the budget.
- `lib/tasks/connection_budget.rake` -- `db:connection_budget[destination]`, with the live `max_connections` comparison.
- `config/database.yml` -- explicit production pool sizes.
- `.dockerignore` -- keeps `config/deploy*.yml` in the image so the task runs in a container (secrets in `.kamal` stay out).
- `test/lib/connection_budget_test.rb`, `test/lib/connection_budget_task_test.rb` -- the matrix, deploy-file and `puma.rb` cases, env isolation, the task's branches.
- `epic-space-terminal-redesign.md` -- Note with the figures for the author; `deferred-work.md` -- reading-pool entry resolved.

**Review findings:** pass 1 — 2 `bad_plan` (deploy env ignored, `WEB_CONCURRENCY` uncounted) and the deploy-overlap wording, re-derived; 2 rejected lows (Action Cable's 4 worker threads and Solid Cache's expiry thread lease beside Puma's threads: one short query each, a full pool waits rather than fails, and sizing for them moves the contract's figures; both stated in the epic Note). Pass 2 — 2 patches (Puma's figures read from `config/puma.rb`; counted env keys isolated per role), 1 rejected low (the replaced impossible test case). Nothing deferred. Patched by verdict: medium 1, low 1.

**Follow-up review recommendation:** false — no high patched, one medium.

**Verification:** `bin/rails test` 1716 runs, 0 failures, 0 errors; targeted files with `test/config` 66 runs, 0 failures; `RAILS_ENV=development bin/rails "db:connection_budget[staging]"` total 65, limit 80, live allowance 97, exit 0; `bin/rubocop` clean; `zeitwerk:check` and `packwerk check` pass. No system tests (no UI touched).

**Residual risks:** the staging comparison is the author's (`bin/kamal app exec -d staging "bin/rails 'db:connection_budget[staging]'"`, after an image with the `.dockerignore` change is deployed), plus a look at `pg_stat_activity` during a deploy, when a role's old and new containers overlap. The image now ships the deploy files (host names and secret names, no values).
