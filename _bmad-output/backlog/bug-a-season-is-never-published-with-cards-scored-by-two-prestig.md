---
id: bug-a-season-is-never-published-with-cards-scored-by-two-prestig
type: bug
title: "A season is never published with cards scored by two prestige formulas"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: high
severity: P1
estimate: ""
---

# A season is never published with cards scored by two prestige formulas

## Description

On staging, season 2 was published with part of its cards scored by the old prestige formula, so every one of them fell into common. Each card-season now records the version of the formula that scored it, and publishing refuses a draft scored by more than one version, with a message telling the administrator to rescore the latest import.

## Acceptance Criteria

Verify: a draft scored by one version, or written entirely before versions, publishes; a mixed draft writes nothing, stays a draft and shows the mixed-versions message, also in the calibration preview.

## References

- plan — _bmad-output/backlog/bug-a-season-is-never-published-with-cards-scored-by-two-prestig-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
