---
id: 35
tracker_status: in-progress
tracker_id: 264
remote: https://github.com/theiereman/gameble/issues/264
type: story
title: "The collection entry shows the completed sets"
parent: epic-screen-walkthrough
after: [34]
hitl: true
risk: low
---

# The collection entry shows the completed sets

## Description

The collection entry gains a section for the sets the player has completed, below EN COURS, asked by the author on 2026-10-26 while reviewing the set tiles: without it a complete set leaves the entry and is only found again by a search. The section takes the same two-faced set progress tile as EN COURS (`library/_set_progress_tile`), loaded in the same lazy frame. A complete set's tile: the rank chip reads COMPLET in its colour, the recto shows its cards as for a set in progress (all of a set of five or fewer, else the three best and "+N"), the gauge is full and the line under it reads that the set is complete in place of "Plus que X pour Y"; the verso shows the tier path with every node reached, the card last gained and "VOIR L'ALBUM". The gold frame stays on EN COURS only. DESIGN.md (Collection entry, Set progress tile) and EXPERIENCE.md (Collection opening) record the section.

## Acceptance Criteria

Verify: On the desktop and the phone, in French and in English, a player with complete sets sees them as tiles in their section under EN COURS, every one of them, most recently completed first; a player without one sees no empty section; the tiles turn and link to their album like EN COURS's; the library request test, the system test for the entry (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Assumed by the agent on 2026-10-26, to confirm with the author on staging: the section is titled COMPLÉTÉS / COMPLETED; it is ordered by the latest card gained in the set (the moment it was completed, as no completion date is stored), most recent first; it shows every complete set with no cap; it is hidden when empty.
