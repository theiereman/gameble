---
tracker_id: ""
key: ""
type: epic
title: "Packs and reveal"
parent: initiative-gameble
covers: [CAP-4, CAP-5, CAP-16]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Packs and reveal

## Description

The core loop: a player's bank holds pre-drawn packs, the attic shows the chest and the timer, and opening a pack plays the dust, seal and flip reveal. The daily bonus adds a booster to the bank.

## Outcome

For a player: ten packs waiting at sign-up, one more every ten minutes, and a reveal worth opening. The signal is the spec's 200 ms p95 on pack opening.

## Requirements

Completed at this epic's inception. The source lines are CAP-4, CAP-5 and CAP-16 of the spec.

## Done when

1. A new player finds ten packs in the chest and gets a sapphire or better by the tenth.
2. Opening a pack delivers five cards drawn in advance and adds them to the collection; opening without an available pack is refused.
3. The reveal shows dust by the age of the game, a rarity seal when wiped, and the game when flipped, on desktop and on phone; "flip all" never skips a legendary.
4. Card art is the vertical Steam image, pixelated and reduced to 16 colours in the browser.
5. Once a day, a player collects a bonus booster; a second attempt the same UTC day is refused.
6. Pack opening answers within 200 ms at the 95th percentile.

## Boundaries

The pack bank, draws and holdings in `Game`, the attic screen, the reveal React island, the card component and the image filter package. Not the library or card detail (epic-collection-and-sharing).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-7, AD-9, AD-16, AD-17
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, sections Component Patterns, Interaction Primitives, Key Flows (Flow 1)

## Notes

- Open question: odds of the daily bonus booster (spec).
- Unknown: the final art of the attic; the author generates it from `ux-gameble/art-prompts.md`.
