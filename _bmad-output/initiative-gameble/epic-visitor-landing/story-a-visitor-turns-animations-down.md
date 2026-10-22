---
id: 9
tracker_status: done
tracker_id: 174
remote: https://github.com/theiereman/gameble/issues/174
type: story
title: "A visitor turns animations down"
parent: epic-visitor-landing
covers: [R4]
after: [2]
hitl: false
risk: medium
---

# A visitor turns animations down

## Description

Adds the top bar's « Animations réduites » switch for visitors, written through a POST into the motion cookie the server reads from the first paint on every signed-out page, and sets the account's setting at sign-in when the switch is on.

## Acceptance Criteria

Verify: A visitor who switches it on gets the reduced landing on the next load without a flash, and after a Steam sign-in their account's reduced motion setting is on; switched off, sign-in leaves the account as it was.

## References

- parent — _bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing.md
