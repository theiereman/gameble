---
id: 36
tracker_status: in-progress
tracker_id: 265
remote: https://github.com/theiereman/gameble/issues/265
type: story
title: "The set tiles turn with an iris and EN COURS loads six at a time"
parent: epic-screen-walkthrough
after: [34, 35]
hitl: true
risk: medium
---

# The set tiles turn with an iris and EN COURS loads six at a time

## Description

The author's staging review of the set tiles (2026-10-27) found the turn too fast and ugly, a transparent gap in the middle of it, tier counts overflowing their square, and the full list heavy to load. Four changes to the tiles of the collection entry and the public profile, decided from `ux-gameble/mockups/key-set-tile-motion-and-path.html`: (1) the turn is replaced by a soft-edged iris with a luminous ring (mockup A12 + A14) opening from where the pointer enters the tile, from the centre on keyboard focus, a plain fade under reduced motion, never on touch, and no `visibility` trick that leaves a gap; (2) the verso's tier path is the mockup's B2: small circles, the line lighting up in proportion to the cards owned, each tier showing the number of cards required to reach it, no negative number; (3) EN COURS loads its first six sets and a Load more button adds the next six, the gold frame staying on the one set closest to its next tier of the whole list; (4) the entry's search no longer shows the old result rows nor looks into the catalogue: it filters the tiles of EN COURS and COMPLETED already on the page, loading every remaining set first when a query is typed.

## Acceptance Criteria

Verify: In the browser, with a pointer, keyboard focus and reduced motion, a tile opens as an iris with its ring from the pointer or the centre, with no moment where the tile is empty; the verso's path shows circles, the lit line following the cards owned and the required counts for 3-digit tiers without overflow; a player with more than six sets in progress sees six, then six more per click, and the search narrows the tiles of both sections; the request and system tests for the entry and the public profile, `bin/rails test` and `npm run test:js` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Decisions of the author, 2026-10-27: iris and ring from the cursor (A12 + A14); B2 for the path with required counts only; six sets then a Load more button; the search filters the displayed tiles instead of the old result rows.
- Assumed by the agent on 2026-10-27, to confirm: Load more adds six sets per click; typing in the search first loads every remaining set so the filter covers them all; a set the player has not started is no longer found by the search (the old rows listed catalogue sets).
