---
id: bug-a-card-glare-fades-where-it-is-when-the-pointer-leaves-inste
type: bug
title: "A card glare fades where it is when the pointer leaves, instead of sliding back to the centre"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P3
estimate: ""
---

# A card glare fades where it is when the pointer leaves, instead of sliding back to the centre

## Description

When the pointer left a tilting card, its glare slid back to the centre of the card while it faded. The glare now fades where it is, as it appears in place under the pointer when the hover starts.

## Acceptance Criteria

Verify: after the pointer leaves an off-centre glare, every frame writes the same glare offset while the tilt eases back to rest, and the next hover places the glare under the new pointer at once.

## References

- plan — _bmad-output/backlog/bug-a-card-glare-fades-where-it-is-when-the-pointer-leaves-inste-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
