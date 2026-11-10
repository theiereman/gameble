---
title: 'Refactor sweep'
type: 'refactor'
ticket: '40.12'
created: '2026-11-10'
status: 'built'
baseline_revision: '201fbbafebe814eb2aa42a3512f776857d1ed132'
route: ''
route_source: ''
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/epic-follow-auctions-and-removed-players.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-refactor-sweep-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 40 and the price stories of epic 41 left a few doc comments on the new price classes, the same accessible PiCoin label built in seven places, the four market race tests repeating one teardown, and three notice handlers each reading the event time the same way, while the player stream repeats the listing's bidders in four branches.

**Approach:** Behaviour-preserving cleanups only: drop the remaining explanatory comments from the new classes, one helper for the accessible PiCoin label, one purge helper for the race tests, one way for the notice handlers to take the event time, and the bidders lookup named once in the player stream. No behaviour, copy or schema change.

## Boundaries & Constraints

**Always:**
- Rendered text, notice rows, stream payloads and refusals stay identical; tests keep asserting the same things and only references follow a rename.
- Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS); no epic 40 file is near its limit (largest: `PlayerStream`, 132 lines), so none is split.
- Every renamed or moved constant or method is changed in `app/` and `test/` together.

**Never:**
- No new feature, no change to a refusal, a locale string or a view; scope pushed out of another story is a new story.
- No comment added; the only comments kept are on epic 38 classes and on external constraints.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- Comments are dropped only from classes epics 40 and 41 created (`CollectionPrices`, `EditionPrices`, `RefreshEditionPrices`); the notice, handler, stream, `VoidLead`, `WithdrawListing`, `ForfeitBalance` and `ListingEnding` classes already carry none.
- The accessible label becomes `PicoinsHelper#picoins_label`, which the six helpers and `PicoinAmountComponent` call.
- The race tests' shared teardown becomes `LockRaces#purge_market_race`, beside the existing purge helpers.
- Handlers read the event time through `Notice.record_at(event, ...)`, which only supplies `at:`.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/collection_prices.rb`, `edition_prices.rb`, `operations/game/market/refresh_edition_prices.rb` -- remaining explanatory comments
- `app/helpers/picoins_helper.rb` and the helpers and component that build `picoin_amount.accessible` -- duplicated label
- `test/support/lock_races.rb` and the four `*_race_test.rb` files of the market -- duplicated teardown
- `app/domains/game/app/models/game/market/notice.rb` and the three notice handlers -- duplicated event time
- `app/models/player_stream.rb` -- the listing's bidders looked up in four branches

## Tasks & Acceptance

**Execution:**
- [x] price classes -- drop explanatory comments
- [x] `picoins_helper.rb` and its callers -- one accessible label
- [x] `lock_races.rb` and the four race tests -- one purge helper
- [x] `notice.rb` and the handlers -- one event time reading
- [x] `player_stream.rb` -- name the bidders lookup once

**Acceptance Criteria:**
- Given any page, notice or stream notice rendered before, when rendered now, then the result is the same.
- Given the race tests, when read, then each holds only its own setup and assertions.

## Implementation Notes

No epic 40 file is near the size limit, so none was split. The notice, handler, stream, `VoidLead`, `WithdrawListing`, `ForfeitBalance` and `ListingEnding` classes already had no comments. `purge_market_race` also clears notices and the card's edition prices for every race test; the rows are absent in the tests that never create them. Nothing was run beyond static checks.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c` on each touched file, `script/check_planning_references`, `script/check_file_sizes` -- expected: no errors
