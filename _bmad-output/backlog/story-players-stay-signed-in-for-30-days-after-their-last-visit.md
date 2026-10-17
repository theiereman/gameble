---
id: story-players-stay-signed-in-for-30-days-after-their-last-visit
type: story
title: "Players stay signed in for 30 days after their last visit"
parent: none
covers: []
after: []
assignee: ""
refined: false
hitl: false
risk: medium
estimate: ""
---

# Players stay signed in for 30 days after their last visit

## Description

Closing the browser signed the player out. A player now stays signed in for 30 days after their last visit, each visit pushing the expiry further, and signing out still ends the session at once. The privacy notice's cookie sentence says so in both locales.

## Acceptance Criteria

Verify: signing in sets a session cookie expiring about 30 days ahead, a later visit pushes it forward, and signing out clears it.

## References

- plan — _bmad-output/backlog/story-players-stay-signed-in-for-30-days-after-their-last-visit-plan.md

## Notes

- Filed on 2026-10-17, after a build that ran without a ticket; the plan beside this file is the record of that build.
