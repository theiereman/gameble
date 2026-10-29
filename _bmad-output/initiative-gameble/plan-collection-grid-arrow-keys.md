---
title: 'Arrow keys move focus within the collection grid'
type: 'bugfix'
ticket: ''
created: '2026-10-29'
status: 'built'
baseline_revision: '5bc6f527fe329e7e2e63518b017b14b9b2c22bd1'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The collection grid at `/library/cards` (and a player's whole collection on their public profile, which renders the same `library/_grid` partial) has no arrow-key navigation: every card link is its own tab stop, while EXPERIENCE asks for one tab stop with arrow keys inside, as the set album's grid already has (`grid-keys` controller).

**Approach:** Put the `grid-keys` controller on the collection grid's `<ol>` as the album does, and teach the controller to give links appended later (the next pages arriving by Turbo stream into `#collection-slots`) a tabindex of -1, so the grid stays one tab stop after a page is appended. Cover it with a system test: one tab stop, ArrowRight, ArrowDown, End, then the same after a page is appended.

</frozen-after-approval>

## Implementation Notes

Oneshot: about 40 lines across the grid partial, the Stimulus controller and a system test. Bugs found alongside it in `deferred-work.md` were checked first: the card back from another player's album (fixed by 3b22f2dd), the settings back after a language change (links replace the history entry, and the trail compares labels across languages) and the album's « ◀ CAPSULE » after a set celebration (asked by EXPERIENCE's set celebration section) do not reproduce or are by design.

After the review, the card detail's Sets list from another player's album links to that player's albums instead of the viewer's (author, 2026-10-29), committed separately.

## Verification

**Commands:**
- `bin/rails test test/system/library_test.rb test/system/collection_set_test.rb test/system/public_profile_test.rb` -- expected: no failures
- `npm run test:js && npm run format:check && npx tsc --noEmit` -- expected: no failures

## Review Triage Log

Quick review, one pass: 1 medium, 2 low, all patched.

- medium, patched: the test pressed End on page 1, whose focus scroll already reaches the next-page nav's 50 % margin, then scrolled to the pages again, so a third page could land and break the slot count or the last focus. The test now appends by scrolling before any End press.
- low, patched: arrow keys were not pressed on appended cards and no Tab press proved the single tab stop. The test now presses ArrowDown from card 60 into the appended page and Tab out of the grid.
- low, patched: nothing guarded the controller on the public profile's whole collection; `public_profiles_controller_test.rb` asserts `ol#collection-slots[data-controller=grid-keys]`.
