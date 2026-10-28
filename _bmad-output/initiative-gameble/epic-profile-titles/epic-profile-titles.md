---
remote: https://github.com/theiereman/gameble/issues/316
tracker_id: 316
key: ""
type: epic
title: "Profile titles"
parent: initiative-gameble
covers: [CAP-22]
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
---

# Profile titles

## Description

Players earn profile titles, shown to everyone, from the tiers and completion of their sets, and choose the one they wear. The source is the titles half of CAP-22 of the spec; its menu themes half is epic-menu-themes.

## Outcome

For a player: their collecting shows on their profile, in the feed and in trades.

## Requirements

Source: CAP-22 of the spec, AD-25 of the architecture.

- R1. Each tier of a set and its completion unlock a profile title, read from the player's set-tier rows and never stored as text: the tier's rank for a tier ("Adepte · Roguelike"), "Complétiste" for completion. Bronze, silver and gold reached in an earlier season give the titles Apprenti, Adepte and Maître, so a set has one title per rank, earned by either. A title is earned once per set and rank, whatever the seasons, and shows the latest season it was earned in. Source: CAP-22, AD-25; author, 2026-10-14 and 2026-10-19.
- R2. The player picks one active title, kept on their player state. Source: CAP-22.
- R3. The active title shows on the player's profile, in the feed and in trades. Source: CAP-22.

## Done when

1. Each tier and the completion of any set unlock a profile title; one active title shows on the profile, in the feed and in trades.
2. A title is earned once per set and rank across seasons; an earlier season's bronze, silver or gold gives the same title as the Apprenti, Adepte or Maître tier.
3. All of it is live in production.

## Boundaries

Titles in `Game`, their picker and their display. Not the tier and completion events (epic-recognizable-sets publishes them), not card backs (epic-card-backs), not menu themes (epic-menu-themes).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-22
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md; EXPERIENCE.md, Profil et paramètres

## Notes

- Decision (2026-10-28, author): split out of epic-card-backs, which it follows, in release 1.2.0.
- Decision (2026-10-28, author): the menu themes leave this epic for epic-menu-themes, which needs refining first; this epic keeps the titles.
- Decision (2026-10-28, author): a UX session settles the title picker's layout before the picker is built; entry 2 waits on it.
- Decision (2026-10-14, author): titles are counted by set kind, key and tier across seasons and show the latest season they were earned in (change-season-carryover).
- Decision (2026-10-19, author): one title per set and rank, the tier's rank as title ("Adepte · Roguelike") (change-set-tiers-by-size).
- Waits on epic 9 because: the author placed it after the card backs epic.
- Waits on epic 13 because: titles are read from the set tier and completion rows.
