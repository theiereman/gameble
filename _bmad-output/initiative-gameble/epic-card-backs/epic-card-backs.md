---
tracker_id: ""
key: ""
type: epic
title: "Cosmetics: card backs, titles and menu themes"
parent: initiative-gameble
covers: [CAP-20, CAP-22]
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
---

# Cosmetics: card backs, titles and menu themes

## Description

Players earn card backs by reaching gold on a theme or hall of fame set, contributing to a successful weekly goal, some achievements, and events or seasons, and choose the one their face-down cards wear. They also earn profile titles, shown to everyone, from set completions and tiers, and rare menu themes from sets at gold.

## Outcome

For a player: a visible reward for completing sets and for taking part in the Brotherhood.

## Requirements

Completed at this epic's inception. The source lines are CAP-20 and CAP-22 of the spec; the back catalogue is in `DESIGN.md`, Card backs.

## Done when

1. Every account has the Standard back; a locked back states its unlock condition.
2. Reaching a theme or hall of fame set's back tier (its first tier at or above half its cards; gold in earlier seasons), contributing to a successful weekly goal and the listed achievements unlock their backs, once each. A back earned again in a later season gains that season's mark, not a second unlock.
3. The player picks one active back in the profile; it shows on their own face-down cards from the next pack opened, and faded on the detail of a card they do not own. The player picks the season mark the active back wears.
4. An administrator can grant a back to a group of players for an event.
5. Each tier and the completion of any set unlock a profile title; one active title shows on the profile, in the feed and in trades. A title is earned once per set and tier across seasons.
6. Completing 3, 10 and 25 sets unlocks a menu theme; the player picks one; contrast is checked for each.

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
- Decision (2026-10-08, author): renamed from "Card backs"; backs unlock on gold, titles and menu themes join (CAP-22, change-recognizable-sets). The folder keeps its name. Waits on epic-recognizable-sets for the set tier and completion events.
- Decision (2026-10-14, author): backs and titles carry season marks; a back is unlocked once and gains a mark per season it is earned in; titles are counted by set kind, key and tier across seasons (change-season-carryover). epic-seasons-carry-over waits on this epic for the backs its recap lists.
- Decision (2026-10-19, author): set tiers cut by set size (change-set-tiers-by-size): a set's back unlocks on its back tier, its first tier at or above half its cards (gold in earlier seasons); titles for each tier and the completion of any set, the tier's rank as title ("Adepte · Roguelike"), earlier seasons' bronze, silver and gold keeping Apprenti, Adepte and Maître; menu themes on 3, 10 and 25 complete sets. Done when 2, 5 and 6 amended; waits also on the tier table by set size (13.22).
