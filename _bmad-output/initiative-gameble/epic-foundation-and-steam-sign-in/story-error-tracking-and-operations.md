---
id: 9
type: story
title: "Error tracking and operations"
parent: epic-foundation-and-steam-sign-in
covers: [R7]
after: [8]
hitl: true
risk: low
---

# Error tracking and operations

## Description

Adds Sentry, a rate limit on the sign-in endpoints, and Mission Control Jobs reachable by administrators only.

## Acceptance Criteria

Verify: A forced error in production appears in Sentry, and the jobs dashboard refuses a non-administrator.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md
