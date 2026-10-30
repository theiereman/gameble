---
tracker_id: ""
type: epic
title: "Steam related features"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
status: done
---

# Steam related features

## Description

Features that connect a gameble card to the player's Steam account and to the game's Steam page. Added to release 1.1.0 by the author, 2026-10-27; the first one lets a player add the game of a card to their Steam wishlist.

## Outcome

A player who likes a card's game can act on it in Steam without leaving gameble more than needed.

## Requirements

No capability of the spec yet: the epic starts from its first ticket.

- R1. A player can add the game of a card to their Steam wishlist from gameble.
- R2. A player signed in with Discord, Google or email can link their Steam account from the settings; a Steam id already held by another player is refused, with no account merge. Steam features need this identity.

## Done when

1. R1 holds on the card detail, for a signed-in player, in English and French, with the outcome shown on the card.
2. R2 holds from the settings, in English and French, without a second account.

## Boundaries

Steam related features only. Nothing in the 0.5.0 release.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md

## Notes

- Decision (2026-10-27, author): milestone 1.1.0 now holds the gameplay extensions and "Steam related features"; the mobile version moved to 1.3.0.
- Closed (2026-10-30, author): R2 holds and shipped in v1.0.0; R1 is dropped, since Steam has no API that writes a wishlist for a third-party site (23.1). Done when 1 is waived with it.
