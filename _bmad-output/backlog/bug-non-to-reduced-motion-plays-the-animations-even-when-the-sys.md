---
id: bug-non-to-reduced-motion-plays-the-animations-even-when-the-sys
type: bug
title: "\"Non\" to reduced motion plays the animations even when the system asks for less"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: low
severity: P2
estimate: ""
---

# "Non" to reduced motion plays the animations even when the system asks for less

## Description

« Animations réduites » offers SYSTÈME, OUI and NON, but NON behaved like SYSTÈME: a player whose system asks for reduced motion got it whatever they chose. NON now plays every animation even then, OUI reduces them, SYSTÈME follows the system, and a signed-out visitor's choice works the same way.

## Acceptance Criteria

Verify: with the system asking for reduced motion, a player or visitor on NON sees the animations and one on OUI does not; SYSTÈME follows the system.

## References

- plan — _bmad-output/backlog/bug-non-to-reduced-motion-plays-the-animations-even-when-the-sys-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
