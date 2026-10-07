---
tracker_id: ""
key: ""
type: epic
title: "Card backs"
parent: initiative-gameble
covers: [CAP-20]
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
---

# Card backs

## Description

Players earn card backs by completing sets, contributing to a successful weekly goal, some achievements, and events or seasons, and choose the one their face-down cards wear.

## Outcome

For a player: a visible reward for completing sets and for taking part in the Brotherhood.

## Requirements

Completed at this epic's inception. The source line is CAP-20 of the spec; the back catalogue is in `DESIGN.md`, Card backs.

## Done when

1. Every account has the Standard back; a locked back states its unlock condition.
2. Completing a set, contributing to a successful weekly goal and the listed achievements unlock their backs, once each.
3. The player picks one active back in the profile; it shows on their own face-down cards from the next pack opened, and faded on the detail of a card they do not own.
4. An administrator can grant a back to a group of players for an event.

## Boundaries

The back catalogue in code, unlocks and the active back in `Game`, the back picker, and the exported back assets. Not the events that unlock them (epics 6 and space-terminal redesign publish them).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-20
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-10, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Card backs; EXPERIENCE.md, Profil et paramètres

## Notes

- Open question: which backs ship and their unlock rules (spec).
- Decision (2026-10-05): its own epic after epic 6, once every unlocking event exists. Approved by the author.
- Decision (2026-10-07): this epic is not part of the MVP; it is built after the public launch (author). Epics 5 and 6 publish the events it will consume (SetCompleted, the goal reward, achievements).
