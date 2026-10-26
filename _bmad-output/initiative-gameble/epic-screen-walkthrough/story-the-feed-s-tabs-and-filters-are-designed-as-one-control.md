---
id: 31
tracker_status: done
tracker_id: 259
remote: https://github.com/theiereman/gameble/issues/259
type: story
title: "The feed's tabs and filters are designed as one control"
parent: epic-screen-walkthrough
after: []
hitl: true
risk: low
---

# The feed's tabs and filters are designed as one control

## Description

On the activity feed (`app/views/feeds/show.html.erb`) the TOUS and AMIS tabs and the filter row (Tout, Tirages, Découvertes, Échanges, Reposts) look dropped on the page at random, with no visible hierarchy between the tabs and the filters (author, 2026-10-23, on staging). Design them as one controlled zone: with the author, settle what the tabs and the filters are (a scope, then a kind), how they align with the list below them and with the page's other filter zones (the catalog's FILTRES chips), how the selected state reads, and how a visitor's greyed AMIS tab looks; the phone keeps them reachable without a wall of chips; EXPERIENCE.md's Fil d'activité row and DESIGN.md follow.

## Acceptance Criteria

Verify: The feed's tabs and filters read as one zone with a clear selected state, aligned with the list, on the desktop and the phone, in French and in English, for a player and for a visitor with the AMIS tab greyed and disabled; keyboard order and accessible names unchanged or improved; checked by the author on staging; the feed system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 24), author, 2026-10-23.
- Settled by the author, 2026-10-24: TOUS and AMIS become two chips on the same line as the kind chips (Tout, Tirages, Découvertes, Échanges, Reposts), set apart from them by a divider, drawn like the catalog's FILTRES chips.
