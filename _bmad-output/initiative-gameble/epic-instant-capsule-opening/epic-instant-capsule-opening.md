---
tracker_id: ""
key: ""
type: epic
title: "Instant capsule opening"
parent: initiative-gameble
covers: []
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
status: in-progress
---

# Instant capsule opening

## Description

Opening a capsule no longer waits for the server. The capsule screen already holds the next capsule of each reserve, cards and faces included, so a touch blasts the capsule, deals the cards and reveals them at once; the opening is confirmed to the server in the background, safely retried until it lands, and the set tiers, goals and celebrations arrive with that confirmation. Around it, everything else that can stall an opening is taken off the path: the art of the next capsule is prepared ahead, the countdown refreshes without reloading the screen, the capsule screen opens offline, and each card leaving the capsule gives a light haptic tap in the apps.

## Outcome

For the players: touching a capsule answers instantly, on a slow phone network as on fibre, and a lost connection no longer cancels an opening or loses its reveal.

## Requirements

No capability of the spec: author request of 2026-11-06 after the UX session on offline opening (option B chosen, option A rejected).

## Done when

1. A touch on a capsule blasts it and deals its cards with no network round trip; the cards reveal with their art without waiting for the server.
2. The opening is confirmed to the server in the background by the capsule's token and an idempotency key, retried after a failure, a reload or a return online until it lands, and never opens a capsule twice or another capsule than the one shown.
3. Set tiers, goals, first copies and celebrations come from the server's confirmation; when the server answers other cards (a season published in between), the hand follows the server.
4. The countdown at zero, the reserve and the next capsules refresh without reloading the screen, and the capsule screen opens offline with the last known reserve.
5. In the native apps, the touch and each card leaving the capsule give a haptic tap.

## Boundaries

The draw stays on the server: packs are drawn when they enter the bank, as today. The next capsule's cards are readable in the page before the opening (accepted by the author). No change to odds, reserves or the reveal's animations beyond removing the wait.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- UX session — https://claude.ai/artifact/8QCfKMgp5dqRPdz1GLsxe4, "Rendre l'ouverture instantanée" and "Aller plus loin que B"

## Notes

- Decision (2026-11-06, author): option B, the capsule's content is sent before the touch; option A (optimistic animation waiting for the server's faces) rejected.
- Decision (2026-11-06, author): also add a light haptic tap per card as the cards leave the capsule in cascade.
- Decision (2026-11-06, author): build the whole set through the BMAD workflow and push to develop.
