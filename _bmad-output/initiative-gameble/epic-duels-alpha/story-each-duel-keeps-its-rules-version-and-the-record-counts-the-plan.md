---
title: 'Each duel keeps its rules version, and the record counts the rules in force'
type: 'feature'
ticket: '5'
created: '2026-11-20'
status: 'built'
baseline_revision: 'face9ca4b85a7ecb88de5c499a70ca115157a0c4'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A duel does not record which rules it was played under, so once the rules change the player's record and history would mix duels played under different rules.

**Approach:** `Game::DuelRules::VERSION = 1`; a `game_duels.rules_version` integer column (not null, default 1, one migration: existing duels read as version 1 through the default); `AcceptChallenge` and `StartPracticeDuel` write the constant when the duel starts; `Game::DuelRecord` and `Game::RecentDuels` (the Duels screen's history through `DuelHistory`) count only finished non-practice duels at `DuelRules::VERSION`. The duel achievement metrics in `Game::DuelAchievementMetrics`, which share the SQL fragments but are withheld during the alpha, keep their behaviour: the version filter is added in `DuelRecord`, not in the shared fragment.

</intent-contract>

## Implementation Notes

Oneshot: about 40 lines across the rules constant, one migration, two operations, two queries, `db/schema.rb` and tests.

- `app/domains/game/app/models/game/duel_rules.rb` -- `VERSION = 1`.
- `db/migrate/20261120150000_add_rules_version_to_game_duels.rb` -- `add_column :game_duels, :rules_version, :integer, null: false, default: 1`; a non-volatile default is safe for strong_migrations on Postgres 18 (target version 18).
- `db/schema.rb` -- version `2026_11_20_150000`; `t.integer "rules_version", default: 1, null: false` after `bot_archetype`. Edited by hand; the coordinator regenerates it from the migrations and diffs.
- `app/domains/game/app/operations/game/accept_challenge.rb`, `start_practice_duel.rb` -- `rules_version: DuelRules::VERSION` in the start `update!`. A challenge sent under one version and accepted under the next takes the version in force at acceptance, the duel's start.
- `app/domains/game/app/queries/game/duel_record.rb` -- its own `OWN_DUELS` fragment = `DuelAchievementMetrics::OWN_FINISHED_DUELS` plus `duel.rules_version = DuelRules::VERSION`; wins no longer reuse `DuelAchievementMetrics::SQL[:duels_won]`.
- `app/domains/game/app/queries/game/recent_duels.rb` -- `rules_version: DuelRules::VERSION` in the duel filter.
- Tests: `test/domains/game/duel_record_test.rb` (a duel at an older version left out of the record and of the last results), `test/models/duel_history_test.rb` (the history leaves it out), `test/domains/game/duel_challenge_operations_test.rb` and `test/domains/game/practice_duel_test.rb` (a started duel holds the current version). Practice never counting is already covered by `practice_duel_test.rb` ("counts in no record or history"). The repo has no migration-level tests.

Assumptions (recorded for the author):
- Forfeited duels count as they do today (finished, with a result); the ticket leaves them as built.
- An "older version" in tests is `DuelRules::VERSION - 1` (0 today); no check constraint bounds the column, since nothing writes it but the constant.
- The withheld duel achievement metrics are left unfiltered: they grant nothing during the alpha, and whether the beta's achievements count across versions is the beta's call.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 1, false 1, maybe-false 0
- findings:
  - `[false]` `[reject]` `db/schema.rb` hand-edited against the regenerate-only rule — the build was told not to run migrations; the edit matches what the dumper writes for a last `add_column` (column after `bot_archetype`, version `2026_11_20_150000`) and the coordinator regenerates the schema from the migrations and diffs before commit to `develop`, so no drift reaches CI.
  - `[medium]` `[patch]` the "starts at the current version" assertions pass on the column default alone, without the operations' write — the acceptance test now sets the challenge to `DuelRules::VERSION - 1` before accepting, so it fails unless `AcceptChallenge` writes the constant. The practice test stays default-equal: `StartPracticeDuel` builds a new row, and forcing a different default there would mean redefining the model attribute in a parallel suite.
  - `[low]` `[patch]` duel test helpers (`active_duel`, the controller test's `finished_duel` built on it) rely on the default 1 and would read as an older version once `VERSION` rises — `active_duel` in `test/support/duels.rb` now sets `rules_version: Game::DuelRules::VERSION`.

## Verification

**Commands (run by the coordinator, not this build):**
- `bin/rails test test/domains/game/duel_record_test.rb test/models/duel_history_test.rb test/domains/game/duel_challenge_operations_test.rb test/domains/game/practice_duel_test.rb` -- expected: pass
- `RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && diff tmp/migrated_schema.rb db/schema.rb` -- expected: no diff

## Auto Run Result

**Summary:** each duel stores the rules version it is played under. `Game::DuelRules::VERSION = 1`. `game_duels.rules_version` is an integer, not null, with default 1, so existing duels read as version 1. `AcceptChallenge` and `StartPracticeDuel` write the constant when the duel starts. `Game::DuelRecord` and `Game::RecentDuels`, which back the Duels screen's record and last results through `DuelHistory`, count only finished non-practice duels at the current version. The withheld duel achievement metrics share the SQL fragments and are unchanged.

**Files changed:**
- `app/domains/game/app/models/game/duel_rules.rb` -- `VERSION = 1`.
- `db/migrate/20261120150000_add_rules_version_to_game_duels.rb` -- the column, not null, default 1.
- `db/schema.rb` -- version and column, edited by hand.
- `app/domains/game/app/operations/game/accept_challenge.rb`, `start_practice_duel.rb` -- write the version at the start.
- `app/domains/game/app/queries/game/duel_record.rb` -- its own version-filtered fragment.
- `app/domains/game/app/queries/game/recent_duels.rb` -- the version filter.
- `test/support/duels.rb` -- `active_duel` at the current version.
- `test/domains/game/duel_record_test.rb`, `test/models/duel_history_test.rb` -- a duel at an older version is left out.
- `test/domains/game/duel_challenge_operations_test.rb`, `test/domains/game/practice_duel_test.rb` -- a started duel holds the current version.

**Review findings:** 2 patches applied (1 medium, 1 low). Nothing deferred. 1 rejected: the hand-edited schema was ordered by the coordinator, who regenerates it.

**Follow-up review recommended:** false. One medium was patched and no high.

**Verification:** no tests, linters or migrations were run, by the coordinator's instruction. `ruby -c` passed on every changed Ruby file. The coordinator still has to run:
- the commands under Verification;
- packwerk;
- `script/check_planning_references`;
- `script/check_file_sizes`.

**Residual risks:**
- `db/schema.rb` is hand-edited: diff it against a regenerated dump.
- The practice test cannot tell the operation's write from the column default while both are 1.
