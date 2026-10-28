---
title: 'A set''s back unlocks on its back tier'
type: 'feature'
ticket: '2'
created: '2026-10-28'
status: 'built'
baseline_revision: 'd0c7deb518615307ad60da73a9139fded30f0188'
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

**Problem:** The 47 set backs are in the catalogue (9.3) but nothing unlocks them: a player who reaches a theme or hall of fame set's back tier never receives its back, and neither does one whose tier was carried into a new season or reached before this epic ships.

**Approach:** A Game handler answers `SetTierReached`, `SetCompleted` and `SeasonAllocationReceived` by enqueueing `Game::GrantCardBacksJob`, as `Handlers::Achievements` enqueues `GrantAchievementsJob`. The job unlocks, through `Game::UnlockCardBack`, the back of every theme or hall of fame set whose back tier the player holds (the first tier at or above half the set's cards; the only tier, complete, for a set under five cards), once per set kind and key across seasons. A carried tier unlocks silently (the unlock event is retroactive). `game:backfill_card_backs` runs `Game::BackfillCardBacksJob` to grant the earlier ones with no toast, in the shape of `game:backfill_achievements`. Franchise, studio and UFO sets grant nothing.

</frozen-after-approval>

## Implementation Notes

Oneshot: about eighty lines of code that mirror the achievements path (handler, job, backfill job, rake task) plus one query. The ticket text names a job fed by a handler, so the unlock is not written inside the handler.

## Plan Change Log

## Review Triage Log

Own diff review (no subagent available). Checked: the back tier query (first tier whose required count is at least half the complete count; a set under five cards has only complete), idempotence (unlock twice writes once, through the existing unique row and `already_unlocked`), banned and deleted players skipped, franchise, studio and UFO sets and themes outside the catalogue grant nothing, constant `Handlers::CardBacks` does not shadow `Game::CardBacks` for any other handler.
- low, rejected: a tier event that is not the back tier still enqueues one cheap job that finds nothing new; filtering in the handler would duplicate the back tier rule.
- Allocation receipts pass `retroactive: true` so a carried tier unlocks with no toast and no feed line; the unlock event is the only event written.

## Verification

**Commands:**
- `bin/rails test test/domains/game/grant_card_backs_test.rb test/domains/game/card_backs_test.rb` -- expected: pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean
