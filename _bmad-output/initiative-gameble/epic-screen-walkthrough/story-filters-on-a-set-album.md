---
id: 23
tracker_status: done
tracker_id: ""
type: story
title: "Filters on a set album"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# Filters on a set album

## Description

A set album (`app/views/library/_album.html.erb`, `set.html.erb`) shows every card of the set in order, and a large set can lose the player (author, 2026-10-23, on staging, "maybe" to confirm). Offer filters on the album, starting from the folded FILTRES zone the catalog already has (`app/views/library/_filters.html.erb`): at least owned or missing, and rarity. With the author, settle the filters, whether the album also gets a search, and how a filtered album keeps the tier bar and the owned / total line unchanged; the grid keeps the set order and the missing-card slots, the back button still returns where the album was opened, and EXPERIENCE.md's Set album and Filter zone rows follow.

## Acceptance Criteria

Verify: On a set of more than 30 cards, filtering by missing shows only the missing-card slots and by a rarity only that rarity, the tier bar and the owned / total line do not change, clearing the filters restores the set order, the back button and focus behave as before, signed in and on a public profile's album; the album system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 15), author, 2026-10-23: to confirm that filters are wanted; the author said "peut-être".
- Settled by the author, 2026-10-24: filters are wanted; owned or missing and rarity, taken from the catalog's folded FILTRES zone, plus a search by game name in the album.
