---
title: 'Two streak achievements over capsules and daily bonuses'
type: 'feature'
ticket: '7'
created: '2026-11-02'
status: 'built'
baseline_revision: '298782326899162e0b4209282a23c90f4e373f73'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Luck Is a Marketing Concept (ten standard capsules in a row with no Rare or better card) and Leave Request Denied (the daily bonus collected seven UTC days in a row) are approved but not in the catalogue.

**Approach:** Two longest-run metrics in `Game::AchievementProgress` (gaps-and-islands over opened `regular` packs in `opened_at` order, and over `game_daily_bonus_claims` days), two catalogue entries, `GrantAchievementsJob` also following `Game::DailyBonusCollected`, copy in both locales, and the clover and refused glyphs drawn in `script/pixel_art/export.mjs`. Their card backs come with entry 11.

</intent-contract>

## Implementation Notes

Oneshot: about 80 lines of code plus tests. Metrics `capsules_without_rare_streak` and `daily_bonus_streak`; keys `luck_is_a_marketing_concept` and `leave_request_denied`; glyphs `clover` and `refused` mapped in `AchievementsHelper`. Existing exact counts (14 to 16), the countable-tile list, the tenth-opening unlock list and the trigger job count were updated. Tests were written but not run by the build agent.

## Plan Change Log

## Review Triage Log
