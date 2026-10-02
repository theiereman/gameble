---
id: 6
type: story
title: "Steam sign-in"
parent: epic-foundation-and-steam-sign-in
covers: [R1, R4]
after: [3, 4]
hitl: true
risk: medium
---

# Steam sign-in

## Description

Adds sign-in through OmniAuth and omniauth-openid: `Steam` verifies the response, `Accounts::SignIn` creates or reuses the player and publishes `Accounts::PlayerRegistered` (the event that later fills a new player's pack bank), and the session is an encrypted cookie holding the player id.

## Acceptance Criteria

Verify: On production, signing in with a Steam account creates a player and signing in again reuses it; no password is stored.

## References

- parent — _bmad-output/initiative-gameble/epic-foundation-and-steam-sign-in/epic-foundation-and-steam-sign-in.md

## Notes

- Unknown: omniauth-openid 2.0.2 is not verified on Rails 8.1; if it fails, the OpenID check is written inside the Steam pack, as the spine allows.
