---
tracker_id: ""
key: ""
type: epic
title: "Profile titles and menu themes"
parent: initiative-gameble
covers: [CAP-22]
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
---

# Profile titles and menu themes

## Description

Players earn profile titles, shown to everyone, from the tiers and completion of their sets, and choose the one they wear; completing 3, 10 and 25 sets unlocks a rare menu theme only they see. The source is CAP-22 of the spec.

## Outcome

For a player: their collecting shows on their profile, in the feed and in trades, and long-time collectors dress their menus.

## Requirements

Completed at this epic's inception. The source lines are CAP-22 of the spec.

## Done when

1. Each tier and the completion of any set unlock a profile title; one active title shows on the profile, in the feed and in trades.
2. A title is earned once per set and rank across seasons; an earlier season's bronze, silver or gold gives the same title as the Apprenti, Adepte or Maître tier.
3. Completing 3, 10 and 25 sets unlocks a menu theme; the player picks one; contrast is checked for each.
4. All of it is live in production.

## Boundaries

Titles and menu themes in `Game`, their pickers and their display. Not the tier and completion events (epic-recognizable-sets publishes them), not card backs (epic-card-backs).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-22
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md; EXPERIENCE.md, Profil et paramètres

## Notes

- Decision (2026-10-28, author): split out of epic-card-backs, which it follows, in release 1.2.0; about four stories (titles derived from tier rows, the title picker and its display in the feed, profile and trades, the menu theme constant with a contrast check, the theme picker), planned at its inception.
- Decision (2026-10-14, author): titles are counted by set kind, key and tier across seasons and show the latest season they were earned in (change-season-carryover).
- Decision (2026-10-19, author): one title per set and rank, the tier's rank as title ("Adepte · Roguelike"); menu themes on 3, 10 and 25 complete sets (change-set-tiers-by-size).
- Waits on epic 9 because: the author placed it after the card backs epic.
- Waits on epic 13 because: titles are read from the set tier and completion rows.
