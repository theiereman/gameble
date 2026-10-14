---
tracker_id: ""
key: ""
type: epic
title: "Every card of the game, browsable and searchable"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: "envelope"
---

# Every card of the game, browsable and searchable

## Description

A "Toutes les cartes" screen lists every card of the game, not only the ones a player owns, so anyone can look through what exists and search for a game. The envelope only records the intent; its scope, its screen and its requirements are worked out with the author in a dedicated session before inception.

## Outcome

For a player or a visitor: they can find out whether a game is a card, and see what it looks like, without having pulled it; the signal is that the screen answers a search for a game by name.

## Done when

1. A "Toutes les cartes" screen lists every card of the published season, owned or not.
2. A search by game name narrows the list as it is typed, and an empty result says so.
3. Each card in the list opens its card detail.
4. The screen and its search work in French and in English, on a phone and on a desktop.

## Boundaries

The browsing and the search of the game's cards. Not the player's collection and its sets (epic-space-terminal-screens, epic-recognizable-sets), not trading or selling cards.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-6 (the collection's grid of every card) and CAP-7 (the card detail)
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Information Architecture, row "Toutes les cartes"

## Notes

- Decision (2026-10-14): the epic is added as an envelope; it is detailed in a dedicated session with the author before inception (author).
- Open question: how this screen relates to the collection's existing "TOUTES LES CARTES" grid (CAP-6): a new screen beside it, or that grid opened to every card of the game.
- Open question: who reaches it (signed-out visitors or players only), and from where (the hub, the "Plus" menu, the collection).
- Open question: which seasons it covers (the published one only, or past seasons too) and what a card shows to a player who does not own it (face, missing slot, owned count).
- Open question: whether searching goes beyond the game's name (studio, franchise, theme, rarity filters), and whether this needs a new capability in the spec; `covers` is empty until then.
- Waits on epic 10 because: the collection's card grid, its filters and the card detail screen exist there.
- Decision (2026-10-14, author): the screen reads one card per game across editions, as the collection does (13.15, change-season-carryover); this settles the seasons part of the open question above for owned cards.
- Waits on epic 13 because: one card per game across editions (13.15).
