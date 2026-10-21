---
title: 'Refactor sweep'
type: 'refactor'
ticket: '12'
created: '2026-10-21'
status: built
baseline_revision: 'a4f0ff71d410579fe1d315eeccd10f39c63cc089'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'auto'
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The epic's build records and the review findings deferred during it leave small debts; none had been settled.

**Approach:** Every deferred finding found in the epic's plans and in `deferred-work.md` is fixed, recorded as left open on purpose, or dropped with a reason. Only cleanup: no behaviour, markup or copy changes.

</frozen-after-approval>

## Implementation Notes

Oneshot: one dead CSS rule to remove, the rest is a disposition of findings. Dispositions:

- Fixed: the ticker's `:focus-within` pause (`app/frontend/styles/shell.css`): the ticker is hidden from assistive technology and holds nothing focusable, so the rule could never apply.
- Dropped, passing today: the two DST-dependent tests (`sessions_controller_test.rb`, `trades_of_test.rb`) pass on 2026-10-21 with their files run whole.
- Dropped, covered: the loop-boundary join of the ticker is checked by `app/frontend/lib/ticker.test.ts`; no further review is planned.
- Dropped, superseded: the pull sentence for non-pull feed kinds (the feed now has every kind); the reward-with-claim-button story replaced the grant-time pack draw; the reward odds question has its own table and an approved entry in `pending-approvals.md`.
- Left open on purpose, each a product or design call for the author: the 900-row bound of the public feed's window; the community goal's 10 s broadcast without change detection; the goal's figures on a bold figure token (the typography audit entry in `deferred-work.md` already covers it and the change would resize them); friends-only entries not broadcast live; the ticker's placement wording in the design document; a held achievement toast lost when leaving the booster mid-reveal; achievements granted live after an unban; one grant job per opening, trade, repost and set completion; the toast region under a modal in the top layer; `game:benchmark_open_pack` still to run; a trade credited to its recipient's row; the friends tab's empty line when the player has friends but no entries; the filter chips' `aria-current` against the design document's `aria-pressed`.
- Left open, negligible by earlier review: an entry shown twice when a page renders between a commit and its job; the discovery insert's sequence gaps; a reposted pack's REPOSTER offer on a traded-away card (refused server-side); the handler failing the opening on a database error (by design).
- Not verified here: the `#community-goal-progress` `display: contents` layout in a browser, the `:has()` requirement and the version label floating over a scrolled band; they need a visual check by the author.

## Verification

**Commands:**
- `npm run typecheck` and `npm run test:js` -- expected: green
- `bin/rails test` -- expected: green
