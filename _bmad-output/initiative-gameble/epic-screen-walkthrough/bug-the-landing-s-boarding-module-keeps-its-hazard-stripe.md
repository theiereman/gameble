---
id: 12
tracker_status: done
tracker_id: 240
remote: https://github.com/theiereman/gameble/issues/240
type: bug
title: "The landing's boarding module keeps its hazard stripe"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: true
risk: low
---

# The landing's boarding module keeps its hazard stripe

## Description

Module 09 ("Embarquer sur le pont", `app/views/landings/_boarding.html.erb`) wears the hazard stripe through `landing-hazard` on its panel, as the support panel does; the repetition and the difference from the plain modules 07 and 08 weaken it (author, 2026-10-23, on staging). Remove the stripe from the boarding panel only, keeping its brackets, its copy and its sign-in actions, and keep DESIGN.md's Landing section in step.

## Acceptance Criteria

Verify: Module 09 shows no hazard stripe on the desktop and the phone, in French and in English, checked by the author on staging; the landing's system test and the full suite pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 2), author, 2026-10-23.
