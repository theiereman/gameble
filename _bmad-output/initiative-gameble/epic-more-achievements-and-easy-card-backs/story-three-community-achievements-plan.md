---
title: 'Three community achievements'
type: 'feature'
ticket: '9'
created: '2026-11-02'
status: done
baseline_revision: '0c4e5b2d7912f4ebe2166737d03c528e3afcd987'
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

**Problem:** First Claim, All Rights Reserved (a first-discovery row), A Discovery of Ours (a repost of a card-season the player first discovered) and A Strictly Professional Relationship (three accepted trades with one partner) are approved but not in the catalogue.

**Approach:** Three community metrics in `Game::AchievementProgress` over `game_first_discoveries`, `game_feed_entries` joined to them, and `game_trades` grouped by partner; three catalogue entries; `GrantAchievementsJob` also following `Game::CardDiscovered`; copy in both locales; the flag, lens and clasp glyphs drawn in `script/pixel_art/export.mjs`. The Contrat back comes with entry 11.

</intent-contract>

## Implementation Notes

Oneshot: about 60 lines of code plus tests. Metrics `first_discoveries`, `pioneered_reposts` (same player, same card-season) and `most_trades_with_a_partner`; keys `first_claim_all_rights_reserved`, `a_discovery_of_ours`, `a_strictly_professional_relationship`; glyphs `flag`, `lens`, `clasp`. Existing exact counts (18 to 21), the to-earn list, the countable-bar list and the trigger job count (7 to 8) were updated. Tests were written but not run by the build agent. The quick review found nothing to change: the repost join requires the reposting player to be the discoverer, and trades are grouped by the other party whichever side proposed.

## Plan Change Log

## Review Triage Log
