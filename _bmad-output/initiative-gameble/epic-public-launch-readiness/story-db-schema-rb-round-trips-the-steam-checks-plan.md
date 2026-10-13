---
title: 'db/schema.rb round-trips the Steam checks'
type: 'bugfix'
ticket: '35'
created: '2026-10-13'
status: done
baseline_revision: '1f4d44e8a2bb74fb2585682c8edaf9f2e8609443'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      Nothing stops a new migration from writing a list check as `col IN (...)`, whose dumped form CI's drift step rewrites.
    evidence: |-
      The intent names a new `IN` check as a way the drift returns; the only guard is the comment in db/migrate/20261002210000_create_catalog.rb, missed by twelve later migrations. The fix (a Known pitfalls line in AGENTS.md or a lint rule) edits agent-context files.
    location: >-
      AGENTS.md
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A check written `col IN ('a', 'b')` on a varchar column is stored by PostgreSQL 18 as `col::text = ANY (ARRAY['a'::character varying, ...]::text[])`; db/schema.rb holds the other form, `ARRAY['a'::character varying::text, ...]`, which is what loading that text stores. So a database built by running the migrations dumps those checks differently from one loaded from db/schema.rb, and whoever dumps from a migrated database (or adds a new `IN` check) gets a schema.rb that CI's load-and-dump drift step rewrites. The ticket names the three Steam checks; running every migration on an empty database (PostgreSQL 18.6, Rails 8.1.4) shows thirteen such checks, the three among them.

**Approach:** One migration drops each of the thirteen `IN` checks and adds it again under its name, unvalidated, written as `col = 'a' OR col = 'b'` (the form `create_catalog` and the role check already use, which PostgreSQL deparses identically whether created from the migration or from db/schema.rb); a second migration validates them. Same allowed values, same names. db/schema.rb is regenerated, never hand-edited. Done when a database built by running every migration and one loaded from db/schema.rb both dump a db/schema.rb identical to the committed one, and a new migration run on a schema-loaded database leaves every check unchanged.

</intent-contract>

## Implementation Notes

Oneshot: two migrations (about 70 lines) and the regenerated db/schema.rb; no application code reads a check's text.

- Evidence at baseline: on an empty database, `SCHEMA=<scratch file> RAILS_ENV=test bin/rails db:migrate` runs all 77 migrations (with no schema file, Rails cannot load one) and its dump differs from db/schema.rb on 13 checks: `accounts_moderation_actions_kind_check`, `accounts_players_visibility_check`, `accounts_reports_reason_check`, `catalog_set_tiers_tier_check`, `catalog_sets_kind_check`, `game_feed_entries_pack_check`, `game_feed_entries_kind_check`, `game_invitations_status_check`, `game_trade_items_side_check`, `game_trades_status_check`, `steam_apps_details_exclusion_check`, `steam_apps_review_exclusion_check`, `steam_import_runs_status_check`. Every other check is already in a stable form.
- Why the ticket's scope is widened from three to thirteen: the ticket's verify asks CI's drift step to pass "from a fresh migrate"; with only the three rewritten, a database built by running the migrations still dumps ten checks differently. The cause and the fix are the same for all thirteen, so they ship together.
- Rails 8.1's `db:migrate` on an empty database loads db/schema.rb before running migrations (`ActiveRecord::Tasks::DatabaseTasks#initialize_database`), so CI's drift step (`db:create db:migrate && git diff --exit-code -- db/schema.rb`) and AGENTS.md's regeneration command never run the existing migrations: they check load-then-dump only. The proof below forces a real run with `SCHEMA` pointing at a file that does not exist.
- At baseline, "load db/schema.rb, run a new migration, dump" already leaves the three checks unchanged (checked with a throw-away migration in a scratch worktree): the ticket's described failure needs a database where the `IN` checks were created by a migration, such as the development database, which holds the `::text[]` form.
- New migrations: `db/migrate/20261013090000_write_list_checks_as_equalities.rb` (for each check: `remove_check_constraint` with its current expression, so the migration stays reversible, then `add_check_constraint` with the OR form, `validate: false`) and `db/migrate/20261013090001_validate_list_checks_written_as_equalities.rb` (`validate_check_constraint` for each).
- Done. The first migration lists each check as table, name, shape, column and values, and builds both the old `IN` expression (for rollback) and the new equalities from them; the shape carries the `IS NULL OR` of the two nullable Steam exclusions and the `(...) = (pack_id ... position ...)` of the feed pack check. Its one-line comment states the PostgreSQL constraint behind it.
- db/schema.rb regenerated with `RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump`: 14 lines change (13 checks and the version); every check now dumps as `col::text = 'a'::text OR ...`.
- Proof, on scratch database `gameble_roundtrip` (dropped afterwards): fresh migrate with `SCHEMA` at a missing scratch file ran all 79 migrations and dumped a file identical to db/schema.rb; `db:schema:load` then `db:schema:dump` identical; CI's step (`db:create db:migrate` on an empty database) left db/schema.rb byte-identical; in a scratch worktree, schema load plus a throw-away migration adding `steam_tags.probe` changed db/schema.rb only by that column and the version. At baseline the fresh migrate differed on the 13 checks.
- Gates: `bin/rails test` 2354 runs, 0 failures; `npm run test:js` 24 files, 225 tests passed; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 695 files, no offenses.
- The development database still holds the `::text[]` forms until `bin/rails db:migrate` runs there; staging and production run the two migrations on deploy.

## Verification

**Commands** (scratch database `gameble_roundtrip`, `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_roundtrip`, never the development database):
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump` on the real test database -- regenerates db/schema.rb from the committed schema plus the two new migrations; the diff holds only the thirteen checks and the version.
- Fresh migrate: drop and create the scratch database, `SCHEMA=<scratch>/real.rb bin/rails db:migrate` (all migrations run), `diff db/schema.rb <scratch>/real.rb` -- expected: identical.
- Schema load: drop, create, `db:schema:load`, `SCHEMA=<scratch>/loaded.rb bin/rails db:schema:dump`, diff -- expected: identical.
- CI's own step on an empty scratch database: `bin/rails db:create db:migrate && git diff --exit-code -- db/schema.rb` -- expected: exit 0.
- New migration on a schema-loaded database: in a scratch worktree, load db/schema.rb, add a throw-away migration adding a column, `db:migrate` -- expected: the db/schema.rb diff holds only that column and the version.
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: green.

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` Nothing prevents a new `IN` check from bringing the drift back — real: CI's load-and-dump flips a fresh `IN` check's `::text[]` form and fails with no hint; the fix is an AGENTS.md pitfall line or a lint rule, an agent-context edit, so deferred (deferred-work.md).

## Auto Run Result

- **Summary:** thirteen checks written `col IN (...)` on varchar columns (the three named Steam checks and ten others with the same cause) are dropped and added again under their names as `col = 'a' OR ...`, unvalidated, then validated; their dumped form is now the same from a run of every migration and from a load of db/schema.rb.
- **Files:** `db/migrate/20261013090000_write_list_checks_as_equalities.rb` (rewrites the thirteen checks, reversible); `db/migrate/20261013090001_validate_list_checks_written_as_equalities.rb` (validates them); `db/schema.rb` (regenerated: 13 checks and the version); `_bmad-output/initiative-gameble/deferred-work.md` (two entries).
- **Review:** quick lens, 1 finding: 0 patched, 1 deferred (medium, no guard against a new `IN` check), 0 rejected. The reviewer independently re-ran the fresh migrate, the schema load and a two-step rollback on its own scratch database: all matched.
- **Follow-up review recommended:** false (no patch applied).
- **Verification:** fresh migrate of all 79 migrations and schema load both dump a file identical to db/schema.rb; CI's step leaves it unchanged; a new migration on a schema-loaded database changes only its own column; `bin/rails test` 2354 runs, 0 failures; vitest 225 passed; zeitwerk, packwerk and rubocop clean.
- **Residual risks:** scope widened from the three named checks to thirteen (author to confirm); the development database keeps the old forms until it is migrated; CI's drift step still never runs the migrations themselves (deferred).
