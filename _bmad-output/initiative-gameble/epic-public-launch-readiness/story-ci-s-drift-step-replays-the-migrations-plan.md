---
title: "CI's drift step replays the migrations"
type: 'chore'
ticket: '43'
created: '2026-10-13'
status: 'built'
baseline_revision: '4ab2658436ebb8e6c5d74a166e473bef90cd75b7'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** CI's "Check migrations are safe" step runs `bin/rails db:create db:migrate && git diff --exit-code -- db/schema.rb` on an empty database, but Rails 8.1's `db:migrate` loads db/schema.rb into a database without `schema_migrations` before migrating (`ActiveRecord::Tasks::DatabaseTasks#initialize_database`, activerecord 8.1.4), so no existing migration ever runs in CI: a migration whose result differs from db/schema.rb (a list check written `col IN (...)`, a column the schema has and no migration adds) passes.

**Approach:** Replace the step with two steps in `.github/workflows/ci.yml`. The first sets `SCHEMA` to a file that does not exist (`tmp/migrated_schema.rb`), so `db:create db:migrate` finds no schema to load, runs every migration and dumps to that file, then `diff -u db/schema.rb tmp/migrated_schema.rb` fails on any difference. The second keeps the load round-trip on an empty database: `db:drop db:create db:schema:load db:schema:dump && git diff --exit-code -- db/schema.rb`. Done when, run as CI runs them, both steps pass on develop, and the first fails on a throw-away `IN` check migration and on a hand edit of db/schema.rb that no migration produces.

</intent-contract>

## Implementation Notes

Oneshot: one CI file, about 15 lines; no application code changes. AGENTS.md is not touched (author's decision, 2026-10-13).

- `.github/workflows/ci.yml`: "Check migrations are safe" becomes two steps. "Check the migrations build db/schema.rb" sets `SCHEMA: tmp/migrated_schema.rb` and runs `rm -f "$SCHEMA" && bin/rails db:create db:migrate && diff -u db/schema.rb "$SCHEMA"` (the `rm -f` keeps a local rerun from loading an earlier dump; `tmp/*` is gitignored). "Check db/schema.rb loads and dumps unchanged" runs `bin/rails db:drop db:create db:schema:load db:schema:dump && git diff --exit-code -- db/schema.rb`, the old check on an explicitly empty database. One-line comment on `SCHEMA` states the Rails behaviour it relies on.
- Both a migrated and a loaded check must match db/schema.rb now, so a list check written `col IN (...)` fails one step whichever form db/schema.rb holds: the migrated `::text[]` form fails the round trip (as before), the load-stable form fails the replay (new).
- Proof harness: a scratch script read each step's `env` and `run` from the workflow file with Ruby's YAML and ran the `run` line verbatim under `bash -e -o pipefail`, overriding only `DATABASE_URL` to `postgres://postgres:postgres@localhost:5433/gameble_t43_scratch` (database dropped before each run, as CI's service starts empty). The old step was run from `git show 4ab2658:.github/workflows/ci.yml`. Scenarios ran in a detached scratch worktree with throw-away commits, so `git diff --exit-code` compared against a committed db/schema.rb as in CI.
- Evidence:
  - develop (main checkout): replay ran all 79 migrations (79 in db/migrate), `diff` silent, exit 0; round trip exit 0.
  - (a1) throw-away migration `add_check_constraint :game_trades, "status IN ('open', 'accepted')", name: "game_trades_probe_check", validate: false`, db/schema.rb regenerated the AGENTS.md way (`::text[]` form): old step exit 1, replay exit 0, round trip exit 1 (diff: `::text[]` against `::character varying::text`).
  - (a2) same migration, db/schema.rb in the form a load-and-dump keeps: old step exit 0 (the gap), replay exit 1 with `-...'accepted'::character varying::text])` / `+...'accepted'::character varying]::text[])` in the diff, round trip exit 0.
  - (b) hand edit of db/schema.rb adding `t.string "probe_note"` to `game_trades`, no migration: old step exit 0 (the gap), replay exit 1 with `-    t.string "probe_note"`, round trip exit 0.
  - Cleanup: scratch worktree removed, `gameble_t43_scratch` and `gameble_ci_replay` dropped, `tmp/migrated_schema.rb` removed; no throw-away file reached the main checkout.
- Gates: `bin/rails test` 2386 runs, 0 failures, 0 errors; `bundle exec packwerk check` no offenses; `bin/rubocop` 698 files, no offenses.
- Review patch: the replay step now starts with `db:drop` (`rm -f "$SCHEMA" && bin/rails db:drop db:create db:migrate && diff -u db/schema.rb "$SCHEMA"`); without it, a database that already holds `schema_migrations` replays nothing and the step only dumps what is there. `config/ci.rb` (`bin/ci`) mirrors both steps ("Migrations: build db/schema.rb", "Migrations: db/schema.rb round trip") in place of its load-only "Migrations: safety", so a local `bin/ci` fails where GitHub Actions does.
- Re-proof after the patch, with no drop between runs: on develop, replay, replay, round trip, replay all exit 0 and each replay runs 79 migrations; (a2) round trip first (leaving a loaded database) exit 0, then replay exit 1 with the `::text[]` diff, 80 migrations run; (a1) replay exit 0, round trip exit 1; (b) round trip exit 0, replay exit 1 with `-    t.string "probe_note"`. `config/ci.rb`'s two migration commands run verbatim (scratch `DATABASE_URL`): develop exit 0 and 0, (b) exit 1 and 0. Scratch worktree removed and `gameble_t43_scratch` dropped again. Gates rerun: `bin/rails test` 2386 runs, 0 failures; packwerk and rubocop (698 files) clean.
- `deferred-work.md`: the two entries from the schema round-trip story (no guard on a new `IN` check; the drift step never runs the migrations) get a `resolved:` line pointing at this ticket.

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 4 findings — high 0, medium 3, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The replay step has no `db:drop`, so on a database that already holds `schema_migrations` it runs no migration and passes without checking anything; it is correct in CI only because it is the first step to touch the fresh service — fixed: the step runs `db:drop db:create db:migrate`; re-proven with the round-trip step run first, the replay then runs 80 migrations and fails on (a2).
  - `[low]` `[reject]` The intent says the first step fails on a throw-away `IN` check, but with db/schema.rb in the migrated `::text[]` form (a1) only the round-trip step fails — the job fails in both forms, as the ticket's verify asks of "the step"; the fix is a wording edit of this build's plan. The Auto Run Result states which step catches which form.
  - `[medium]` `[patch]` `config/ci.rb` (`bin/ci`) keeps the load-only "Migrations: safety", so a hand edit of db/schema.rb or a load-stable `IN` check passes `bin/ci` and fails only on GitHub Actions — fixed: `bin/ci` runs the same two checks; its commands proven on develop (pass) and (b) (replay fails).
  - `[medium]` `[patch]` The first `resolved:` line in deferred-work.md claims more than the step guaranteed (same root cause as the first finding: no `db:drop`) — fixed by that patch; the line now holds.

### 2026-10-13 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` The intent says the first step fails on a throw-away `IN` check, but with db/schema.rb in the migrated `::text[]` form only the round-trip step fails — carried: same location and claim as the first pass's rejected row, and `.github/workflows/ci.yml` still reads as that row describes; the job fails in both forms, and the fix is a wording edit of this build's plan.

## Verification

**Commands** (scratch database via `DATABASE_URL=postgres://postgres:postgres@localhost:5433/<scratch>`, `RAILS_ENV=test`, never the development or test database; each step's `run` line executed verbatim):
- Replay step on develop -- expected: exit 0, no diff.
- Round-trip step on develop -- expected: exit 0.
- A throw-away migration adding a check `col IN (...)` on a varchar column, with db/schema.rb in the form a load-and-dump keeps (the form the old step accepts) -- expected: the old step passes, the replay step fails with the check's `::text[]` form in the diff. With db/schema.rb regenerated the AGENTS.md way instead (`::text[]` form), the round-trip step fails, as the old step did.
- A hand edit of db/schema.rb that no migration produces (an extra column) -- expected: the old step and the round-trip step pass, the replay step fails with the column in the diff.
- `bin/rails test`, `bundle exec packwerk check`, `bin/rubocop` -- expected: green.

## Auto Run Result

- **Summary:** CI's load-only "Check migrations are safe" step is replaced by two steps: "Check the migrations build db/schema.rb" drops the database, runs every migration with `SCHEMA` at a missing `tmp/migrated_schema.rb` (so Rails loads no schema) and diffs that dump against db/schema.rb; "Check db/schema.rb loads and dumps unchanged" keeps the load round trip on a dropped database. `bin/ci` runs the same two checks.
- **Files:** `.github/workflows/ci.yml` (the two steps); `config/ci.rb` (the same two checks for `bin/ci`); `_bmad-output/initiative-gameble/deferred-work.md` (`resolved:` on the two entries from the schema round-trip story); this plan.
- **Review:** quick lens, 4 findings: 3 patched (medium: replay step without `db:drop`; `bin/ci` left load-only; the deferred-work claim resting on the first), 0 deferred, 1 rejected (low: the intent's "the first fails" holds for the load-stable form only; the migrated form fails the round-trip step, so the job fails either way).
- **Follow-up review recommended (first pass):** true. Patched: high 0, medium 3. Unverified risk: none in the CI job itself (each patch re-proven); the step's first real run on GitHub Actions (fresh `postgres:18` service, `tmp/` from `tmp/.keep`) is the remaining unexercised path.
- **Verification:** run as CI runs them on scratch databases: develop passes both steps (79 migrations replayed); an `IN` check fails the replay when db/schema.rb holds the load-stable form (the old step passed it) and the round trip when it holds the migrated form; a hand-edited column fails the replay (the old step passed it); `bin/rails test` 2386 runs, 0 failures; packwerk, rubocop clean.
- **Residual risks:** a list check written `IN` is caught by one step or the other, not always by the replay; AGENTS.md's regeneration command (`db:drop db:create db:migrate`) still loads the schema first and runs only new migrations, unchanged by the author's decision; the replay now runs every migration on each CI run (about 80, a few seconds locally).
- **Follow-up pass (2026-10-13):** quick lens on the change since `4ab2658436ebb8e6c5d74a166e473bef90cd75b7` (commit `28b5b73`). 1 finding, carried as rejected (low: "the first fails on an `IN` check" holds for the load-stable form only; the round-trip step catches the migrated form, so the job fails either way). Patched: high 0, medium 0, low 0; deferred 0. The lens re-ran the replay on develop against a scratch database on 5433 (79 migrations, no diff) and a load-and-dump to a scratch file (matches db/schema.rb), and confirmed the `SCHEMA` path in activerecord 8.1.4 (`schema_dump_path` returns `ENV["SCHEMA"]`; `initialize_database` loads it only when the file exists) and the single test database. No code changed in this pass.
- **Follow-up review recommended:** false. This follow-up pass patched no `high`; the work has converged. The step's first run on GitHub Actions remains the only unexercised path.
