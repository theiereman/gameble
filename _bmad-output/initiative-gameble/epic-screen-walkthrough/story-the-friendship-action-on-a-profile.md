---
id: 6
tracker_status: done
tracker_id: 199
remote: https://github.com/theiereman/gameble/issues/199
type: story
title: "The friendship action on a profile"
parent: epic-screen-walkthrough
covers: [R3]
after: [5]
hitl: false
risk: medium
---

# The friendship action on a profile

## Description

The identity band shows the viewer's one action: « AJOUTER EN AMI » sends an invitation in one click that lands in Amis, « EN ATTENTE » once sent, « ACCEPTER » for an invitation received, « ÉCHANGE » between friends, the trades-closed line for a private viewer, and nothing on one's own profile or for a signed-out visitor.

## Acceptance Criteria

Verify: Request and operation tests show each relation's action, the invitation arriving in the recipient's Amis, acceptance creating the friendship, and a repeated invitation refused.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Component Patterns: Profile action; Copy deck: Public profile
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-10
