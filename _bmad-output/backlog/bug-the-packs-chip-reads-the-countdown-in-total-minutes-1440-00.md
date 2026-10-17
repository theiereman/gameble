---
id: bug-the-packs-chip-reads-the-countdown-in-total-minutes-1440-00
type: bug
title: "The packs chip reads the countdown in total minutes (1440:00) for a pack more than an hour away"
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

# The packs chip reads the countdown in total minutes (1440:00) for a pack more than an hour away

## Description

The top bar's packs chip counted down in total minutes, so a pack more than an hour away read 1440:00. It now reads H:MM:SS from an hour, else MM:SS, on the page as rendered and as it ticks.

## Acceptance Criteria

Verify: a pack 1 h 30 away reads 1:30:00 on the server-rendered chip and on the client tick; under an hour it reads MM:SS; the daily booster's countdown is unchanged.

## References

- plan — _bmad-output/backlog/bug-the-packs-chip-reads-the-countdown-in-total-minutes-1440-00-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
