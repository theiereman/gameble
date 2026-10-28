---
id: 22
tracker_status: done
tracker_id: ""
type: spike
title: "A livelier \"EN COURS\" on the collection entry"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# A livelier "EN COURS" on the collection entry

## Description

The collection opens on the set search and then "EN COURS", the player's sets as plain progress rows (`app/views/library/_set_progress_row.html.erb`, `_entry.html.erb`; EXPERIENCE.md, Collection opening). The author finds the whole collection screen average and these rows sad, without being able to say exactly why (screen walkthrough, 2026-10-23, on staging). With the author, find what makes the screen flat and choose a more engaging way to show the sets in progress (for example the owned cards of a set peeking out, the next tier and its missing cards made the focus, a closest-to-complete highlight), as mockups in `ux-gameble/mockups`; the output is the chosen mock and the DESIGN.md and EXPERIENCE.md changes it needs, and a story to build it. The same rows serve the hub's "SETS EN COURS" and the public profile, so the study covers them.

## Acceptance Criteria

Verify: The author has picked one mockup for the collection entry's sets in progress, the hub panel and the public profile's sets keep to it, DESIGN.md and EXPERIENCE.md record it, and a build story for it is in the tree before epic 12.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 14), author, 2026-10-23; the rest of the collection screen is still to be judged, add what the author names to this study.
