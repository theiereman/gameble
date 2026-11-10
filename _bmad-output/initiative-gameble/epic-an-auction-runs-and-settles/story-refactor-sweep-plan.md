---
title: 'Refactor sweep'
type: 'refactor'
ticket: '39.12'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '07c9c06f8445455860aeb11f0c41fb7e8166c0a8'
route: ''
route_source: ''
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 39 left small duplications and policy slips behind: ListCard and PlaceBid each parse a typed amount and each define the same bigint maximum, the new market classes carry explanatory doc comments the project policy forbids, and the two market race tests repeat the same cleanup helpers.

**Approach:** Behaviour-preserving cleanups only: one shared amount parser for the two operations, the doc comments dropped from the epic's market classes, and one shared cleanup helper for the race tests. No behaviour, no copy, no schema change.

## Boundaries & Constraints

**Always:**
- Error codes, parsing rules (digits only, 1 to the bigint maximum) and the order of steps in ListCard and PlaceBid stay as they are.
- Tests keep asserting the same things; only references follow a rename.
- Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS); no market file is near its limit, so none is split.

**Never:**
- No new feature, no change to a refusal, a locale string or a view; scope pushed out of another story is a new story.
- No comment added; the only comments kept are on earlier epics' classes and on external constraints.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The parser is a private-method module `Game::Market::PriceAmount` beside `ListingReservation`, the same shape as the existing shared operation module; `MAX_AMOUNT` moves into it and the sales controller and the ListCard test name it there.
- Doc comments are dropped only from classes this epic created; epic 38 classes keep theirs, as that epic is built and reviewed.
- The race tests' cleanup helpers move into the existing `LockRaces` support module, which already serves tests that commit for real.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/list_card.rb`, `place_bid.rb` -- duplicated amount parsing and `MAX_AMOUNT`
- `app/controllers/market/sales_controller.rb` -- reads `MAX_AMOUNT` for the plain-amount check
- `test/support/lock_races.rb`, `test/domains/game/market/place_bid_race_test.rb`, `cancel_listing_race_test.rb` -- duplicated purge helpers

## Tasks & Acceptance

**Execution:**
- [x] `price_amount.rb` -- add the shared parser and constant; ListCard and PlaceBid include it
- [x] epic 39 market classes -- drop explanatory doc comments
- [x] `lock_races.rb` and the two race tests -- one copy of the purge helpers

**Acceptance Criteria:**
- Given any amount ListCard or PlaceBid accepted or refused before, when parsed now, then the result is the same.
- Given the race tests, when read, then each holds only its own setup and assertions.

## Implementation Notes

No market file is near the size limit, so none was split. Doc comments were dropped from the epic's operations, models, queries and the bid refusals concern; the epic's other classes were left as built.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c` on each touched file, `script/check_planning_references`, `script/check_file_sizes` -- expected: no errors
