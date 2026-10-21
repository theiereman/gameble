---
id: 10
tracker_status: done
tracker_id: 220
remote: https://github.com/theiereman/gameble/issues/220
type: bug
title: "The Légendaire iridescence lets the card's content show through"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: true
risk: low
---

# The Légendaire iridescence lets the card's content show through

## Description

The iridescent reflection on Légendaire cards (`.card__reflection--iridescence` in app/frontend/styles/card.css, DESIGN.md tokens iridescence-1 to -3) is strong enough that the card's art and text are hard to read (author, 2026-10-20, on staging). Tone it down, its opacity, coverage or blend, so the cover art, title and studio read clearly at every card size while the effect still marks a Légendaire; DESIGN.md records the new strength.

## Acceptance Criteria

Verify: A Légendaire card at grid, m and l sizes shows its art, title and studio clearly with the iridescence visible but subdued, checked by the author on staging; reduced motion unchanged; vitest and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Reported by the author on 2026-10-20: the iridescent effect on Légendaire cards almost hides their content.
