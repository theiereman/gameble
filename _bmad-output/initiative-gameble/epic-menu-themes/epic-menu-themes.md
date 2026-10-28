---
tracker_id: ""
key: ""
type: epic
title: "Menu themes"
parent: initiative-gameble
covers: [CAP-22]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Menu themes

## Description

Long-time collectors dress their menus: completing 3, 10 and 25 sets, of any kind, unlocks a rare menu theme each, an accent colour applied to the interface with its contrast checked, which only the player sees. Split out of the profile titles epic on 2026-10-28 because the idea is still raw: it is refined before it is sliced into stories.

## Outcome

For a long-time collector: their menus wear a theme earned by completing sets.

## Requirements

Not yet written: the epic is refined with the author first (what a theme changes in the interface, how many themes, their colours, how contrast is checked). The source line is CAP-22 of the spec: "Completing 3, 10 and 25 sets, of any kind, unlocks a menu theme each: an accent colour applied to the interface, with contrast checked. Only the player sees it." AD-25 holds the architecture: a theme unlocks when the player's distinct set kinds and keys with a `complete` row reach its count, the active theme is a column of `game_player_states`, and its accent colours are one constant in code, contrast checked.

## Done when

1. Completing 3, 10 and 25 sets unlocks a menu theme each; the player picks one; only they see it; contrast is checked for each.
2. All of it is live in production.

## Boundaries

Menu themes in `Game`, their picker and their application to the interface. Not profile titles (epic-profile-titles), not card backs (epic-card-backs).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-22
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-25
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md; EXPERIENCE.md, Profil et paramètres

## Notes

- Decision (2026-10-28, author): split out of epic-profile-titles because it needs refining; no stories until then.
- Decision (2026-10-28, author): a UX session settles the layout before the stories.
- Unknown: how the accent applies to an interface drawn in a fixed palette, and the colour and name of each theme.
