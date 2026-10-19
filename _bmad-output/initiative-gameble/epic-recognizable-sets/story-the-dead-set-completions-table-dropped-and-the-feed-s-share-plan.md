---
title: 'The dead set completions table dropped and the feed''s share fallback removed'
type: 'chore'
ticket: '26'
created: '2026-10-19'
status: 'built'
baseline_revision: 'ac80a01a6e3a085a6db0c78ac87e610b8a280f51'
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

**Problem:** `game_set_completions` (`Game::SetCompletion`) has had no writes since tiers replaced completions; only `Game::ReleasePlayer` still deletes from it, and the account deletion dialog still names "completed sets" as stored data while the legal page's deletion paragraph lists only part of what deletion erases. The feed's set entry falls back to counting a set's members when the set has no complete tier row, a case only the test helper `insert_four_themes` creates.

**Approach:** Stop every use of `Game::SetCompletion` (delete the model and its delete in `Game::ReleasePlayer`), then drop the table in its own reversible migration (strong_migrations: code first, drop alone) and regenerate `db/schema.rb` from the migrations. The deletion dialog stops naming completed sets (set tiers stay, completions are tier rows); the legal page's deletion paragraph lists the same erased data as the dialog, its date moved to 19 October 2026. The feed's share divides by the complete tier row only (an inner join, no `COALESCE`), and `insert_four_themes` gives Metroidvania a complete row while it stays the highest result. The retired-kinds migration test recreates the table by running the drop migration down, as it already widens the kind check, and the test class named after set completion is renamed.

</intent-contract>

## Implementation Notes

Oneshot: about 80 lines over a dozen files, each change mechanical (a delete, a migration, a SQL join, copy, test fixtures).

- Two commits, in strong_migrations order: the first removes `Game::SetCompletion` and its delete in `Game::ReleasePlayer` and drops the feed's fallback; the second adds `DropGameSetCompletions` (alone in its migration, reversible: its `drop_table` block repeats the create's definition, so a rollback restores the same columns, index and foreign key name), regenerates `db/schema.rb` from the migrations on the scratch database `gameble_schema_w1326`, and corrects the copy.
- The feed's share now inner-joins the complete tier row: a set without one would be left out of the entry rather than sort first, as a NULL share would under `DESC`. Test sets that reach a tier were given complete rows: `insert_four_themes` (Metroidvania now holds the rare card too, gold at 1 of 2; it stays the highest result through the tier-order tiebreak), two sets in `feed_test.rb`, the silver theme in `live_feed_job_test.rb` and `feeds_controller_test.rb`.
- `delete_retired_set_kinds_migration_test.rb` recreates the table in its setup by running the drop migration down (the DDL rolls back with the test's transaction), as it already widens the kind check; beside the migrations, it is the only code left naming the table.
- `first_discovery_and_set_completion_test.rb` renamed `first_discovery_and_complete_set_test.rb` (`Game::FirstDiscoveryAndCompleteSetTest`) so no code names `SetCompletion`.
- Copy: the deletion dialog drops "your completed sets" / "vos sets complétés" (completions are set tier rows, still erased). The legal page's deletion paragraph lacked several erased items; it now lists the dialog's game data (latest activity, set tiers, achievements, daily bonuses, community goal rewards added) and its date moves to 19 October 2026. A new test covers the legal paragraph; the dialog test refuses "completed sets" in both locales.
- `deferred-work.md`: both entries marked resolved.
- `npm install` and `bin/ci` rewrite `package-lock.json`'s name; reverted, never committed.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `delete_retired_set_kinds_migration_test.rb`'s new comment above `restore_completions_table` restates the method name, against the comment rule — comment deleted.
  - `[low]` `[patch]` The dialog test no longer checks that "completed sets" is gone, so the wording could return unnoticed — `assert_no_match(/complétés|completed sets/, note)` added for both locales.

## Verification

**Commands:**
- `grep -rn -E "SetCompletion|game_set_completions" app packs config test lib` -- expected: only the drop migration's test support (the retired-kinds migration test) and no app or pack code.
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate` on `gameble_schema_w1326`, then `cp tmp/migrated_schema.rb db/schema.rb` -- expected: only the `game_set_completions` table and its foreign key leave `db/schema.rb`, plus the version.
- `bin/ci` and `bin/rails test` (through the shared slot), `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks unused` -- expected: all pass.

## Auto Run Result

**Summary:** `Game::SetCompletion` is gone and `game_set_completions` is dropped in its own reversible migration, after the code stopped using it; `db/schema.rb` was regenerated from the migrations. Account deletion still erases the player's set tiers, completions included; the dialog no longer names completed sets, and the legal page's deletion paragraph now lists the same erased game data as the dialog (dated 19 October 2026). The feed's set entry ranks by the tier's share of the complete tier row, with no member-count fallback; the test sets have their complete rows.

**Files changed:**
- `packs/game/app/models/game/set_completion.rb` — deleted.
- `packs/game/app/operations/game/release_player.rb` — no completion delete.
- `packs/game/app/models/game/feed_entry.rb` — share over the complete row, inner join, no `COALESCE`.
- `db/migrate/20261019150000_drop_game_set_completions.rb` — new: drops the table, reversible.
- `db/schema.rb` — regenerated: table, index and foreign key gone.
- `config/locales/en.yml`, `fr.yml` — dialog note without completed sets; legal deletion paragraph completed; legal date.
- Tests: `accounts_controller_test.rb`, `pages_controller_test.rb`, `feed_test.rb`, `live_feed_job_test.rb`, `feeds_controller_test.rb`, `support/game_sets.rb`, `delete_retired_set_kinds_migration_test.rb`, `first_discovery_and_complete_set_test.rb` (renamed).
- `_bmad-output/initiative-gameble/deferred-work.md` — two entries resolved.

**Review findings:** 2 patches applied (low: a restating comment removed; a negative assertion on the dialog copy added). 0 deferred. 0 rejected.

**Follow-up review recommended:** false (patched: high 0, medium 0, low 2).

**Verification:**
- `bin/ci` (shared slot): every step passed (2832 runs, 0 failures) except the schema round trip, which diffs against the repository and failed only because `db/schema.rb` was not yet committed. After the commit and a rebase onto origin/develop, `bin/ci` passed whole (2837 runs, 0 failures, schema round trip included).
- `npm run test:js` 476 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `i18n-tasks unused` and `missing`: clean.
- Drop migration rolled back and re-run on the scratch database: the rolled-back schema equals the baseline's, the re-migrated one equals the committed one.

**Residual risks:**
- Kamal runs migrations as the new container boots while the old one still serves: an account deletion in those seconds would fail on the dropped table (its transaction rolls back) and can be retried.

