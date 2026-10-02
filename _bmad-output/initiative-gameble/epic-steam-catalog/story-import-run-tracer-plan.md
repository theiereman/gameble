---
title: 'Import run tracer'
type: 'feature'
ticket: '1'
created: '2026-10-02'
status: 'built'
baseline_revision: '947517442c4697e8288c5689c19eb6fd4cabc784'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Nothing reads Steam yet: there is no import run, no import queue or worker, and no back-office page from which an administrator starts and watches an import (epic 2, R1, R2).

**Approach:** Add a `Steam::ImportRun` record (status, step, cursor, counts, errors) driven by a self-re-enqueuing job on an `import` queue served by its own Solid Queue process with one thread. Its first and only step for now pages through `IStoreService/GetAppList` (games only) into `steam_apps`, advancing the cursor in the same transaction as the page's upsert. An administrator starts, watches and resumes runs from a back-office page.

## Boundaries & Constraints

**Always:** state changes are operations in `Steam` publishing one event each (AD-3, AD-10); writes are idempotent (upsert on `appid`, cursor committed with its page); one active run at a time, enforced by the database; the API key comes from `STEAM_API_KEY`, falling back outside production to the git-ignored `config/steam_api.key`; the key never appears in logs, errors or the page; administrators only (policy tested for visitor, player, moderator); all copy in `fr` and `en`; Minitest with stubbed HTTP, no real Steam call in tests.

**Never:** no review, store-details or `Catalog` work (stories 2.2–2.5); no code calls Solid Queue directly except configuration (AD-12); no Turbo broadcast from inside a transaction (AD-13); no new HTTP-mocking gem — use Faraday's test adapter.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Start | admin posts start, no active run | run `running`, step `app_list`, first page job enqueued on `import` | — |
| Start twice | a run is pending or running | no new run | `Failure(:run_in_progress)`, flash with `errors.steam.run_in_progress` |
| Page | cursor `last_appid` = N | apps after N upserted, cursor and `apps_listed` count advanced, next page enqueued | — |
| Last page | `have_more_results` false | run `completed`, `finished_at` set | — |
| Worker killed mid-page | page transaction not committed | the job is retried from the same cursor; no duplicate `steam_apps` | Solid Queue releases the claimed job |
| Steam error | 429/5xx | faraday-retry backs off; after retries the run is `failed` with the error appended (key redacted) | admin can resume a failed run from its cursor |
| Not admin | visitor / player / moderator | sign-in redirect / 403 / 403 | policy |

</frozen-after-approval>

## Code Map

- `lib/application_operation.rb` -- base of operations; `transaction`, `publish(event, stream_name:)`.
- `packs/accounts/app/operations/accounts/sign_in.rb`, `.../events/accounts/player_registered.rb` -- golden examples of an operation and its event.
- `packs/steam/` -- holds only sign-in code; add `app/models`, `app/operations`, `app/events`, `app/jobs`, `app/queries`, `app/clients` here. `package.yml` allows `packs/catalog` only.
- `app/controllers/back_office/dashboard_controller.rb`, `app/policies/back_office/*_policy.rb` -- headless policy pattern `authorize [ :back_office, :x ], :show?`; `ApplicationPolicy#administrator?`.
- `app/views/back_office/dashboard/show.html.erb` -- link to the new page for administrators, like the jobs link.
- `config/routes.rb` -- back-office routes live in the `:locale` scope.
- `config/queue.yml`, `config/database.yml`, `config/environments/{development,production}.rb`, `Procfile.dev`, `config/deploy.yml`, `.kamal/secrets` -- queue processes, dev queue database, adapters, deploy roles and secrets (`SENTRY_DSN` pattern).
- `app/frontend/controllers/` -- Stimulus controllers (`attic_controller.ts` as example).
- `test/integration/authorization_test.rb`, `test/policies/` -- policy and refusal tests to mirror.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile` -- add `faraday ~> 2.14.4`, `faraday-retry ~> 2.4.0` (Stack table).
- [x] `db/migrate/*_create_steam_import_runs_and_apps.rb` -- `steam_import_runs` (status, step, cursor jsonb, counts jsonb, error_messages jsonb, started_at, finished_at; partial unique index on status in pending/running) and `steam_apps` (appid unique, name, last_modified, price_change_number, import_run_id).
- [x] `packs/steam/app/clients/steam/web_api.rb` -- Faraday client with retry on 429/5xx, key from config, `get_app_list(last_appid:, max_results:)`; redact the key from raised errors.
- [x] `packs/steam/app/models/steam/{import_run,app}.rb`, `app/events/steam/{import_run_started,app_list_page_imported,import_run_finished}.rb`.
- [x] `packs/steam/app/operations/steam/{start_import,import_app_list_page,fail_import,resume_import}.rb` -- the run's state changes.
- [x] `packs/steam/app/jobs/steam/import_step_job.rb` -- `queue_as :import`; runs the current step's page operation, re-enqueues itself after commit while the run is running; marks the run failed when retries are exhausted.
- [x] `config/initializers/steam.rb` -- `config.x.steam.api_key` from env or key file.
- [x] `config/queue.yml` + `config/queue_import.yml`, `Procfile.dev`, `config/database.yml` (dev `queue` db), `config/environments/development.rb` (Solid Queue), `config/deploy.yml` (`import` role `bin/jobs -c config/queue_import.yml`, secret `STEAM_API_KEY`), `.kamal/secrets` -- the import worker: one process, one thread, `import` queue only; the default worker excludes it.
- [x] `app/controllers/back_office/import_runs_controller.rb`, `app/policies/back_office/import_runs_policy.rb`, views, routes, Stimulus poller, locales -- list runs, start, show one run (status, step, counts, last errors), resume a failed run; the page refreshes itself every few seconds while the run is active.
- [x] `test/` -- operations (success and every failure), job (pages, last page, retry exhaustion, resume from cursor without duplicates), client (key redaction), policy and controller (each role).

**Acceptance Criteria:**
- Given an administrator on the back-office, when they start an import, then the run page shows step `app_list` and an app count that grows without reloading by hand.
- Given a running import, when the import worker is stopped mid-step and restarted, then the count continues from the cursor and `steam_apps` has no duplicate `appid`.
- Given `bin/rails test` and `bin/packwerk check`, when run, then both pass.

## Implementation Notes

- Added `Steam::CompleteImport` (called through `step` by `ImportAppListPage` on the last page) so each operation still publishes one event; `ImportRunFinished` carries `status` completed or failed. `ResumeImport` publishes `ImportRunStarted`.
- `steam_import_runs` also has a `token` (AD-15): run URLs use it, never the id. The one-active-run index is a partial unique index on the constant `(true)` where status is pending or running, so a pending and a running run cannot coexist either.
- Queries `Steam::ImportRunById`, `ImportRunByToken`, `LatestImportRuns`; the job derives from `ActiveJob::Base` (the pack cannot reach the root `ApplicationJob`). `retry_on StandardError, attempts: 3` then `FailImport` with the message redacted.
- The default worker lists `queues: [ default ]` (Solid Queue cannot exclude a queue): a new queue must be added to `config/queue.yml`.
- Solid Queue 1.7 releases a claimed job only on graceful shutdown. A worker killed with SIGKILL (or crashing) gets its job marked failed (`ProcessExitError` / `ProcessPrunedError`), no Active Job retry runs, and the run stays `running`. Verified locally; recovery is retrying the failed job in Mission Control (verified: the run finished from its cursor with no duplicate). Documented in the README.

- Matrix audit (orchestrator): Solid Queue 1.7 does not hand back the job of a worker killed outright (`ProcessExitError`, or `ProcessPrunedError` after its heartbeat expires), so the "worker killed mid-page" row was not met. Added `Steam::StalledImportRuns` (running, unmoved for 10 minutes) and `Steam::RecoverStalledImportsJob`, scheduled every 5 minutes in `config/recurring.yml` (development and production), which re-enqueues the page job; the `cursor_moved` guard stops a duplicate. Tests: `test/jobs/steam_recover_stalled_imports_job_test.rb`. README updated.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 2, low 3, false 0, maybe-false 0, rejected 1

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | `RecoverStalledImportsJob` piles up page jobs that become permanent extra chains | Confirmed: `ImportAppListPage` read the cursor fresh, so a duplicate imported the next page and re-enqueued itself. Fixed: `ImportStepJob` carries the cursor it was enqueued for; a job whose cursor is not the run's stops before calling Steam (`cursor_moved`). Test: three piled recoveries make one chain. |
| 2 | medium | patch | A malformed GetAppList answer (`{}`, not JSON, no `response`) completes the run with a partial list | Confirmed: `get_app_list` defaulted to `{}`, which `more_pages?` read as the last page. Fixed: the client raises `Steam::WebApi::Error`, so the job retries then fails the run. Tests for four malformed bodies. |
| 3 | low | patch | `more_pages?` ignores the highest-appid fallback that `advance` uses when Steam omits `last_appid` | Confirmed. Fixed: `more_pages?` compares the computed `next_appid`. Test added. |
| 4 | low | patch | `aria-live` on the `<dl>` inside the frame is replaced on every poll, so nothing is announced | Confirmed. Moved `aria-live="polite"` to the `turbo-frame`, which stays in place. |
| 5 | low | patch | The system test never clicks "Start an import" (AC 1) | Confirmed. The system test now goes through the dashboard link and the start button. |
| 6 | false | rejected | AC 3 names `bin/packwerk`, which has no binstub | Its only fix edits this build's plan; `bundle exec packwerk check` (the CI form) passes. |


## Design Notes

A page is one job: the operation upserts the page and moves the cursor in one transaction, then the job enqueues the next page after commit. A killed worker leaves the last committed cursor, so the retried job re-fetches the same page and the upsert absorbs it. `GetAppList` is ordered by appid and returns `last_appid`, which settles the entry's unknown: the cursor is that value. Use `include_games=true` and nothing else, so DLC, software and videos never enter `steam_apps`.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green.
- `bin/packwerk check && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

**Manual checks (if no CLI):**
- `bin/dev` with the jobs and import processes, sign in as administrator, start a run on `/fr/back-office/import-runs`, watch the count grow, kill the import process, restart it, and check `Steam::App.count == Steam::App.distinct.count(:appid)`.
