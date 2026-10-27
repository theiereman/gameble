---
id: 34
tracker_status: done
tracker_id: 263
remote: https://github.com/theiereman/gameble/issues/263
type: story
title: "EN COURS shows sets as two-faced tiles"
parent: epic-screen-walkthrough
after: [22]
hitl: true
risk: medium
---

# EN COURS shows sets as two-faced tiles

## Description

The collection entry's EN COURS (`app/views/library/_entry.html.erb`, today a list of `library/_set_progress_row`) becomes a grid of set progress tiles, as the author chose in the study of 2026-10-26 (`ux-gameble/mockups/key-collection-in-progress.html`; DESIGN.md, Set progress tile; EXPERIENCE.md, Set progress tile and Collection opening). Each tile has two faces of one fixed size; the recto's header shows the rank (the highest tier reached, or AUCUN PALIER) and the verso's the cards owned out of the total; the recto shows the set's cards at a readable size (every card for a set of five or fewer, missing ones as silhouettes in their rarity's faded colour; otherwise the three best owned and "+N"), the gauge with its tier ticks and "Plus que X pour Y"; the verso shows the set's tier path, the card last gained in the set (from the holdings' `last_gained_at`) and "VOIR L'ALBUM". Hover or keyboard focus turns the tile, reduced motion fades it, touch never turns it; the first tile, the set closest to its next tier, wears the gold frame. Two columns on the desktop, one below 720px; the tile's accessible name stays the row's progress sentence. EN COURS shows every set in progress, loaded after the page (a lazy Turbo frame or the like) while the search stays usable; the public profile's SETS (`app/views/public_profiles/_sets.html.erb`, `MOST_COMPLETE_SETS_SHOWN`) take the tile too, six sets instead of twenty, without the card last gained; the hub and the search results keep `library/_set_progress_row`. Server-rendered, both faces in the HTML, the turn in CSS with a small Stimulus controller only if focus handling needs one.

## Acceptance Criteria

Verify: On the desktop and the phone, in French and in English, EN COURS shows tiles that match the mockup for a large set, a set of five cards or fewer and a set without tiers; hover and keyboard focus turn a tile without moving the grid, reduced motion fades it, a tap on the phone opens the album; the library system tests (retrying matchers) and the full suite pass; checked by the author on staging.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Chosen by the author on 2026-10-26 after the pistes A (vedette), B (étagère) and C (tuiles) and several recto and verso studies: the "vitrine et chemin" pair.
- Settled by the author, 2026-10-26: (1) the public profile's SETS take the tile and show the six most complete started sets instead of twenty; the hub's SETS EN COURS and the search results keep the rows; (2) EN COURS shows every set in progress, with no cap, loaded asynchronously after the page so the search is always usable; (3) on another player's public profile the tile is the same, without the card last gained.
