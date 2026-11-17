---
title: 'Ten duel achievements and the Duelliste card back'
type: 'feature'
ticket: '3'
created: '2026-11-17'
status: 'built'
baseline_revision: '940317c64aa1a7d9c787a2f3e62497f71f7d07f9'
route: 'full'
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

**Problem:** Finished duels reward nothing the way the rest of the game does: no achievement follows a duel and no card back is earned from duels.

**Approach:** Ten achievements join `Game::Achievements`, their metrics read from finished duels, seats and rounds by `Game::AchievementProgress`; `GrantAchievementsJob` follows `Game::DuelFinished` for both seats; the Duelliste back, drawn through the pixel art script, is unlocked by Abuse of Dominant Position.

## Boundaries & Constraints

**Always:** Keys never change; titles and conditions in both locales; a round won by the winner's own automatic move counts for neither Valuation Error nor Certified Versatility, while a duel counts once it ends, automatic moves included; the Duelliste art comes from `node script/pixel_art/export.mjs`, never by hand.

**Never:** Build the duel capsule, the duel pack kind, `duel_day` or the Fortune columns (the capsule ticket); touch the duel screen, its views or its CSS.

</intent-contract>

## Code Map

- `app/domains/game/app/models/game/achievements.rb` -- the catalogue, ten entries appended
- `app/domains/game/app/queries/game/duel_achievement_metrics.rb` -- new: the SQL of the seven duel metrics, merged into `METRIC_SQL`
- `app/domains/game/app/queries/game/achievement_progress.rb` -- merges the duel metrics
- `app/domains/game/app/handlers/game/handlers/achievements.rb` -- `Game::DuelFinished` for both seats
- `app/domains/game/app/models/game/card_backs.rb` -- `abuse_of_dominant_position` unlocks `duelliste`
- `app/helpers/achievements_helper.rb` -- a glyph for each new achievement
- `script/pixel_art/export.mjs`, `script/pixel_art/named_backs.mjs` -- two glyphs and the Duelliste design
- `config/locales/en.yml`, `config/locales/fr.yml` -- names, conditions and the back's name

## Tasks & Acceptance

**Execution:**
- [x] Catalogue, metrics, handler, back, glyphs, locales, pixel art as listed in the Code Map.
- [x] Tests: `test/domains/game/duel_achievements_test.rb`, `test/system/duel_achievements_test.rb`, and the existing counts that grew.

**Acceptance Criteria:**
- Given a player whose duel ends with their first win, when the duel finishes, then the toasts of First Dispute Settled Amicably and Competitive Advantage Observed show and both tiles show earned on the achievements screen.
- Given 50 won duels, when the achievement is claimed, then the Duelliste back is unlocked.

## Implementation Notes

Implemented directly in the main session rather than by a subagent: the change was investigated and written in one pass. No migration. The achievements' flavours named by the ticket do not exist in the repository's achievement locale structure (names and conditions only), so none were added. The duel capsule's emblem grid belongs to the capsule ticket; the Duelliste back draws its own blades from the same description. A margin win is a won duel whose stored scores are equal; a round's "own automatic move" is the winner's call when it called, its answer when it answered.

## Plan Change Log

## Review Triage Log

### 2026-11-17 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 3, false 1, maybe-false 0 (one is a design observation, rejected)
- findings:
  - `[low]` `[patch]` Two explanatory comments in `duel_achievement_metrics.rb` — removed, the rounds constant renamed `ROUNDS_WON_BY_OWN_MOVE`.
  - `[low]` `[patch]` The market achievements test lost its strict tail check — it now also asserts the last ten keys are the duel catalogue.
  - `[low]` `[patch]` No test for a round nobody won, nor an all-automatic 10 to 0 win — both added.
  - `[low]` `[reject]` `flag` and `briefcase` glyphs are shared with two earlier achievements — the plan names two new glyphs only; cosmetic, the fix is new art.
  - `[false]` `[reject]` Flavours claim unconfirmed — the ticket's text names flavours, the repository's locale structure has none; recorded in deferred work.

## Verification

**Commands:**
- `bin/rails test test/domains/game/duel_achievements_test.rb` -- expected: passes
- `bin/rails test test/system/duel_achievements_test.rb` -- expected: passes
- `node script/pixel_art/export.mjs --check` -- expected: up to date

## Auto Run Result

- Summary: ten duel achievements, their metrics, the `DuelFinished` trigger for both seats, the Duelliste back (unlocked by Abuse of Dominant Position, claimed like the other achievement backs), glyphs, locales and tests.
- Files: see the Code Map; tests in `test/domains/game/duel_achievements_test.rb` and `test/system/duel_achievements_test.rb`; counts in older tests raised from 30 to 40 achievements.
- Review: 3 patches applied, 0 deferred, 2 rejected.
- Follow-up review recommended: false.
- Verification: duel achievements unit and system tests, controllers, domains, models, lib, jobs, helpers, components and integration suites, vitest, zeitwerk, packwerk, rubocop, format, css lint, planning references, file sizes, `i18n-tasks missing`, pixel art `--check` all pass; `test/integration/error_pages_test.rb` fails on `public/errors/starfield.svg` drift that exists on the base and is unrelated.
- Residual risks: no migration; the 44.1 capsule ticket still adds its own emblem and canister.
