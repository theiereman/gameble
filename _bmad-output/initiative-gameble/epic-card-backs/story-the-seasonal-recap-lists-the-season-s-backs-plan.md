---
title: 'The seasonal recap lists the season''s backs'
type: 'feature'
ticket: '8'
created: '2026-10-28'
status: 'built'
baseline_revision: '6c4cae8460a558e6a783a7cc91a135262909412b'
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

**Problem:** The allocation screen lists the tiers earned and the achievements unlocked in the season that ended, but not the card backs unlocked in it, so a player never sees the backs they won.

**Approach:** `Game::CardBacksEarnedIn.call(player, season, before:)` returns the catalogue backs the player unlocked from the season's publication up to the next season's, oldest first. `Game::SeasonAllocationRecap` carries them as `backs`, and the "Unlocked in season N" section shows them above the achievements, one large row per back: its picture, its name, how it was earned and when. The section appears when it holds a back or an achievement.

</frozen-after-approval>

## Implementation Notes

Oneshot. A back counts for the season whose span holds its unlock time, the rule the achievements already follow on this screen (the unlock table stores only `unlocked_at`). A back received by the allocation itself is unlocked after the next season's publication, so it never shows as earned. Backs missing from the catalogue are left out. The row reuses `card_back_image`, `card_back_name` and `card_back_condition`; the only style added is the large row. No test or check was run in the worktree, by the author's instruction; the coordinator runs them in the main tree.

## Review Triage Log

Self-review of the diff, quick: no high or medium finding. Low: the count of the backs sub-list is the number of backs, as the tiers and achievements lists do; the set back name comes from `SetLabel`, the same text as the picker.

## Verification

**Manual checks (if no CLI):**
- A player with a back unlocked during the ended season sees its row in "Unlocked in season N"; one with only older or newer unlocks sees no backs.
