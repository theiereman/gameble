---
title: 'Refactor sweep'
type: 'refactor'
ticket: 13
created: '2026-11-02'
status: done
baseline_revision: '3ab63449807a60eff18cf0e9797889cd16feaf95'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: ['adversarial']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The epic grew `Game::AchievementProgress` to eighteen SQL metrics that repeat the same card-of-a-capsule join and three copies of the gaps-and-islands streak query, and several tests hard-code the catalogue size.

**Approach:** Extract the repeated SQL into named fragments and one streak builder, and let the count tests read the catalogue size, keeping behaviour, URLs and markup.

</intent-contract>

## Implementation Notes

Oneshot: a small mechanical refactor of one query and three tests.

- `app/domains/game/app/queries/game/achievement_progress.rb`: `OPENED_PACKS`, `OPENED_REGULAR_PACKS`, `DRAWN_CARD_SEASONS`, `DRAWN_CARDS` fragments; `longest_run_sql` and `pack_run_sql` replace three hand-written gaps-and-islands statements. `AchievementProgress.call`, the metric names, the single-statement rule and the `PACKS_OPENED_SQL` / `TRADES_ACCEPTED_SQL` constants used by `ProfileActivity` are unchanged. All metrics were run against the test database with an empty player.
- `test/controllers/achievements_controller_test.rb`, `test/domains/game/achievement_board_test.rb`, `test/domains/game/earned_achievements_test.rb`: the catalogue size comes from `Game::Achievements::CATALOGUE.size` through a method (not a class-body constant) so adding an achievement no longer touches them.
- Left: `Game::FeedTest` flake (deferred by the two-rare plan, needs a seeded parallel reproduction); `script/pixel_art/export.mjs` (1531 lines, `.mjs` is outside `script/check_file_sizes`, and splitting risks pixel output drift); `AchievementsHelper::GLYPHS` (28 lines, already a plain map); the unnormalised `fr.yml` (not blanket-normalised on purpose).

## Review Triage Log

One synchronous adversarial pass: 0 high, 0 medium, 2 low. SQL of every metric judged equivalent to the original, format placeholders safe. Low 1 (new helpers public): patched, made private. Low 2 (tests track the catalogue instead of pinning 23): accepted, `achievements_test.rb` holds the per-achievement checks.

## Verification

- `ruby -c`, rubocop on `app/domains/game` and the touched tests, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `node script/pixel_art/export.mjs --check`: clean.
- Test suites, `bin/ci` and vitest are run once in the main tree.
