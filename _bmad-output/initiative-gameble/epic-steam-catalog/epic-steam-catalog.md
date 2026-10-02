---
tracker_id: ""
key: ""
type: epic
title: "Steam catalog"
parent: initiative-gameble
covers: [CAP-2, CAP-3]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Steam catalog

## Description

The card catalog is built from Steam: an administrator starts an import, watches it, and publishes a season whose cards have a rarity and belong to sets.

## Outcome

For players: a catalog of established Steam games to draw from, whose rarity anyone can explain. For the administrator: an import that can be watched and resumed.

## Requirements

Completed at this epic's inception. The source lines are CAP-2 and CAP-3 of the spec and `catalog-and-rarity.md`.

## Done when

1. An administrator starts an import from the back-office and sees its step, counts and errors while it runs.
2. An interrupted import resumes without restarting and without duplicate cards.
3. Publishing season 1 makes its cards visible at once, each with a rarity tier, a release date, a title and description in French and English, and its sets.
4. No game is in the catalog with fewer than 500 Steam reviews or without a vertical Steam image.
5. The published season contains publisher sets, tomes and "best rated of the year" sets.

## Boundaries

The `Steam` and `Catalog` packs and the import pages of the back-office. Not the display of cards or sets to players (epic-packs-and-reveal, epic-collection-and-sharing).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-4, AD-5, AD-19
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md

## Notes

- Open question: prestige formula and tier thresholds; calibrated on the first real import.
- Unknown: the duration of a full import pass under Steam's rate limit; measured on the first run.
