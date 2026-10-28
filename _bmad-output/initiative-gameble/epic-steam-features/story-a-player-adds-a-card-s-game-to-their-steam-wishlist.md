---
id: 1
tracker_status: dropped
tracker_id: ""
type: story
title: "A player adds a card's game to their Steam wishlist"
parent: epic-steam-features
covers: [R1]
after: []
hitl: true
risk: medium
---

# A player adds a card's game to their Steam wishlist

## Description

On the card detail of a signed-in player, a control adds the card's game to the player's Steam wishlist and shows whether the game is already on it. Steam has no public API that writes a wishlist with an OpenID sign-in or a Web API key: the store's `addtowishlist` endpoint needs the player's own store session. So the story starts by settling with the author how it works: the honest minimum is a button that opens the game's Steam store page where the player presses the wishlist button themselves (and reads the wishlist state back through the public profile's wishlist when the player's profile is public); anything that asks the player for their Steam session cookies is out. The control is an outbound link or a POST that never calls a write on Steam on the player's behalf, with its text in `en.yml` and `fr.yml` and the app's CSP and external-link rules respected.

## Acceptance Criteria

Verify: A signed-in player sees the control on a card detail in English and French; it opens the game's Steam store page in a new tab with no referrer leak the app does not already allow; no Steam session cookie is requested or stored; the controller test and the card detail system test cover it; `i18n-tasks missing` and `unused` are clean.

## References

- parent — _bmad-output/initiative-gameble/epic-steam-features/epic-steam-features.md

## Notes

- Unknown: Whether any official way to write a Steam wishlist exists for a third-party site; if not, whether the outbound link satisfies the author, or whether to read the wishlist state back.
- Asked by the author, 2026-10-27, for milestone 1.1.0.
