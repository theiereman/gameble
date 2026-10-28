---
tracker_id: ""
key: ""
type: epic
title: "Personalization"
parent: initiative-gameble
covers: [CAP-20, CAP-22]
after: []
assignee: ""
risk: low
estimate: ""
estimate_basis: ""
---

# Personalization

## Description

A page, Personnalisation, where a player dresses and shows their collecting: the profile showcase, the card back their face-down cards wear and the profile title they carry. It sits behind the player menu beside the profile and settings screen, which keeps language, visibility, reduced motion, session, data, account and legal. Menu themes join the page later (epic-menu-themes). Decided in the UX session of 2026-10-28.

## Outcome

For a player: one place to choose what their collecting looks like, and a title that shows on their profile, in the feed and in trades.

## Requirements

Source: CAP-20 and CAP-22 of the spec, AD-25 of the architecture, the UX session of 2026-10-28 (DESIGN.md and EXPERIENCE.md, Personnalisation).

- R1. A Personnalisation page behind the player menu holds the sections the pickers fill; the profile showcase moves to it from the settings and is edited there as on the public profile (order and removal). Source: author, 2026-10-28.
- R2. The player picks one active card back on the page, each back showing its state or its unlock condition; it applies from the next pack opened. Source: CAP-20 (the picker was on the settings screen before the session).
- R3. The player picks one active profile title among those earned, or none, and it shows on their profile, in the feed and in trades. Source: CAP-22.

## Done when

1. The player menu opens Personnalisation, which shows the showcase, the card back picker and the title picker; the settings no longer show the showcase.
2. A player equips an unlocked card back and a title they earned; a locked back states its condition; the title shows on their profile, in the feed and in trades.
3. All of it is live in production.

## Boundaries

The page, the two pickers and the display of the title. Not the back catalogue, the unlocks or the booster (epic-card-backs), not how titles are derived (epic-profile-titles), not menu themes (epic-menu-themes).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-20 and CAP-22
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md; EXPERIENCE.md, Personnalisation

## Notes

- Decision (2026-10-28, author): one epic for the Personnalisation page, the card back picker and the title picker; it gathers the entries that were 9.4 and 9.10 of epic-card-backs and 24.2 and 24.3 of epic-profile-titles.
- Decision (2026-10-28, agent's choice, for the author to confirm): the entries that read the active back (9.5, 9.7) no longer wait on the picker, because the active back is stored by 9.1 whatever screen sets it; this keeps the dependency between epic-card-backs and this epic one-way.
- Decision (2026-10-28, author): the title picker lists only earned titles, grouped by rank, with "Aucun titre" first.
- Decision (2026-10-28, author): the showcase is editable on the Personalization page as on the public profile; 26.1 moves it in read-only form and entry 26.6 adds the editing.
