---
id: 25
tracker_status: done
tracker_id: ""
type: story
title: "The signed-in card detail's actions are sorted instead of stacked"
parent: epic-screen-walkthrough
after: [17]
hitl: true
risk: low
---

# The signed-in card detail's actions are sorted instead of stacked

## Description

On the signed-in card detail (`app/views/cards/_detail.html.erb`, `app/views/pages/_showcase_actions.html.erb`) the actions pile up under the facts: "VOIR SUR STEAM" and "PARTAGER" on one row, "REPOSTER" on the next, then "METTRE EN VITRINE" with its "Vitrine pleine" line, four buttons of two visual weights that read as clutter (author, 2026-10-23, on staging, with a screenshot). Sort them: with the author, decide which action is the card's main one, which are secondary, which can fold away (for example behind a single more-actions control) and how the full-showcase line reads; the disabled "METTRE EN VITRINE" must stay understandable. Built on the outcome of 16.17, which moves the buttons out of the information background; EXPERIENCE.md's Card detail row and DESIGN.md follow.

## Acceptance Criteria

Verify: The signed-in card detail on the desktop and the phone, in French and in English, shows the actions in the agreed order and grouping with no stack of equal buttons, with a card in the showcase, a card not in it, a full showcase, and a card not owned; keyboard order and accessible names unchanged or improved; the card detail system tests (retrying matchers) and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 17), author, 2026-10-23, with a screenshot of the actions at the foot of the detail.
- Settled by the author, 2026-10-24: REPOSTER is the card's main action, the one filled button; the showcase, share and Steam actions are secondary.
