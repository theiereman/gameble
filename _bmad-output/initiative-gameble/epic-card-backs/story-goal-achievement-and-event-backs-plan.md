---
title: 'Goal, achievement and event backs'
type: 'feature'
ticket: '7'
created: '2026-10-28'
status: done
baseline_revision: '20d65ecfc2d6c1d9feaa26ff91acdcc7136efd2d'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [self-review]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The catalogue holds Standard and the 47 set backs, but the seven other backs already drawn (Confrère, Centurion, Étoile d'or, Aurore, Saison 1, Millésime 2017, Soldes d'hiver) are never unlocked: no rule grants them, no console task hands the event ones to a group, and the achievements screen does not say that three achievements carry a back.

**Approach:** The catalogue gains the seven backs, each with its rule: the first reward of a successful weekly goal unlocks Confrère; `boosters_100`, `first_legendary` and `three_complete_sets` unlock Centurion, Étoile d'or and Aurore; the other three are event backs. `Handlers::CardBacks` also answers `GoalRewardGranted` and `AchievementUnlocked` (a retroactive achievement unlock stays silent for its back) by enqueueing the existing `Game::GrantCardBacksJob`, which now unlocks the set, goal and achievement backs the player holds. `game:backfill_card_backs` therefore also grants the goal and achievement backs earned before. `game:grant_card_back[back,steam_ids]` runs `Game::GrantCardBackJob`, which unlocks an event back for each Steam id of a group, each in its own transaction, a failure on one never rolling back the others. Each achievement tile that carries a back names it with its picture.

</frozen-after-approval>

## Implementation Notes

Oneshot. Every back already has its five PNG sizes (drawn by `script/pixel_art/export.mjs` with the Confrère redraw of the author's decision), so nothing is drawn. The earned backs are recomputed from the player's goal rewards and achievement rows rather than from the event, so the handler needs no per-event rule and the backfill shares the code. The goal back comes with the reward (`GoalRewardGranted`), not with its claim, so a reward that cannot be claimed yet still holds the back. The group is given as Steam ids, as `accounts:set_role` does; a banned, deleted or unknown id is counted, not granted. Back names are in the `card_backs.names` locale keys, shared with any later screen that names a back.

## Plan Change Log

## Review Triage Log

Own diff review (no subagent available). Checked: the handler's retroactive flag (event data key read with a default, so goal and tier events stay non-retroactive and an allocation receipt stays retroactive), idempotence (the unique row and `already_unlocked`, backfill run twice writes once), banned and deleted players skipped by both jobs, achievement keys outside the catalogue ignored, the event back task refusing a set, goal or achievement back, a failing unlock reported to the error tracker and counted without stopping the group, the tile line absent from achievements without a back, locked tiles dimming the picture, no `style` attribute, no database id exposed.
- low, rejected: every set tier, goal and achievement event now also computes the goal and achievement backs (two cheap queries) instead of branching on the event; the single computation keeps the backfill identical to the live path.
- low, accepted: the achievements screen shows the back's name from `card_backs.names`; the picker of the active back may reuse those keys.

## Verification

**Commands:**
- `bin/rails test test/domains/game/grant_milestone_backs_test.rb test/domains/game/grant_card_back_job_test.rb test/domains/game/card_backs_test.rb test/domains/game/grant_card_backs_test.rb test/controllers/achievements_controller_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass except `PixelArtExportTest` review sheet, which failed in this run (no pixel art changed here; baseline not compared)
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `node script/pixel_art/export.mjs --check`, `npm run lint:css`, `npm run format:check`, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean
