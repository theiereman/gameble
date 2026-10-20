---
id: 5
tracker_status: in-progress
tracker_id: 198
remote: https://github.com/theiereman/gameble/issues/198
type: story
title: "The owner orders the showcase"
parent: epic-screen-walkthrough
covers: [R3]
after: [4]
hitl: false
risk: low
---

# The owner orders the showcase

## Description

On their own profile the owner moves each showcase card one place with ◀ ▶, keyboard included, and the hub follows the first card; the public profile summary in Profil et paramètres shows the chosen cards.

## Acceptance Criteria

Verify: Operation tests show a move changing the order and the hub's card; request tests show no reorder button for anyone but the owner and the settings summary with and without chosen cards.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Component Patterns: Public profile
