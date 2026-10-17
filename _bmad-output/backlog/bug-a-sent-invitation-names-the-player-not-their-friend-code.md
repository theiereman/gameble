---
id: bug-a-sent-invitation-names-the-player-not-their-friend-code
type: bug
title: "A sent invitation names the player, not their friend code"
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

# A sent invitation names the player, not their friend code

## Description

On the Friends screen a sent invitation read « Envoyée à » followed by the recipient's friend code, and sending by code confirmed with the code too. Both now name the player, falling back to the friend code only when the player has no usable name.

## Acceptance Criteria

Verify: a sent invitation's row and the confirmation after sending by code name the recipient; a recipient with no usable name shows the friend code.

## References

- plan — _bmad-output/backlog/bug-a-sent-invitation-names-the-player-not-their-friend-code-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
