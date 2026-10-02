---
id: 7
type: story
title: "Roles, policies and ban check"
parent: epic-foundation-and-steam-sign-in
covers: [R4]
after: [6]
hitl: false
risk: medium
---

# Roles, policies and ban check

## Description

Adds Pundit with the roles visitor, player, moderator and administrator, a ban check on every request, and the rule that a Game operation requires a player.

## Acceptance Criteria

Verify: Tests show a signed-out request to a mutating action is refused, and a banned player loses access at the next request.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md
