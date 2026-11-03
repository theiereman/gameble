---
title: 'Lazy Opener and Hardworking from the reveal streaks'
type: 'feature'
ticket: '10'
created: '2026-11-02'
status: done
baseline_revision: '28d15f8c59a13270fa9eae008871d1a90d775082'
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

**Problem:** Streamlined Opening Procedure (10 capsules in a row opened with "Reveal all") and Diligence Beyond the Call of Duty (10 capsules in a row with every card revealed one by one) are approved but not in the catalogue.

**Approach:** Two longest-run metrics in `Game::AchievementProgress` over opened packs of any kind in `opened_at` order, read from `game_packs.reveal_mode` (a pack without a mode breaks both runs, so nothing is granted from before the column), two catalogue entries after Leave Request Denied, `GrantAchievementsJob` also following `Game::PackRevealed`, copy in both locales from the approved table, and the double-arrow and card-under-a-hand glyphs drawn in `script/pixel_art/export.mjs`. N is 10 for both. Their card backs are not part of this entry.

</intent-contract>

## Implementation Notes

Oneshot. Metrics `reveal_all_streak` and `reveal_one_by_one_streak` share one gaps-and-islands SQL; keys `streamlined_opening_procedure` and `diligence_beyond_the_call_of_duty`; glyphs `skip` and `revealed` mapped in `AchievementsHelper`. The French "Tout révéler" in the table matches the button label in `fr.yml`, so the table is unchanged. Existing counts (21 to 23), the to-earn and progress-bar lists, the countable-tile list (which was already missing the three later countable achievements) and the handler trigger-job count (8 to 9) were updated. Tests were written but not run by the build agent.

## Plan Change Log

## Review Triage Log
