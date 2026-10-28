---
id: 5
tracker_status: done
tracker_id: ""
type: story
title: "The landing shows the season and the weekly goal"
parent: epic-visitor-landing
covers: [R2]
after: [2, 6.3]
hitl: false
risk: medium
---

# The landing shows the season and the weekly goal

## Description

Adds the queries the landing reads (the goal's participants, active players this week, capsules opened today, first discoveries this week) and shows the season panel and module 02's goal panel from them, the end time in the visitor's time zone, each block cached per locale.

## Acceptance Criteria

Verify: The landing shows the published season with its three facts and the current goal with its count, gauge and participants, a second request inside the cache window runs none of the queries, and an empty game shows the designed empty states.

## References

- parent — _bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing.md

## Notes

- Unknown: What « cette semaine » and « aujourd'hui » mean (calendar week or the goal's week, which time zone).
