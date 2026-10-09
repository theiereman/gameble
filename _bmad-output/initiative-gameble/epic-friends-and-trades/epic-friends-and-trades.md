---
tracker_id: ""
key: ""
type: epic
status: done
title: "Friends and trades"
parent: initiative-gameble
covers: [CAP-10, CAP-11, CAP-21]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Friends and trades

## Description

Players send an invitation through an invite link or a friend code and become friends once it is accepted, then trade cards on a face-to-face board, asynchronously, with counter-proposals. A proposal holds an offer and a request, with quantities. Cards placed in a trade are reserved.

## Outcome

For two friends: swapping cards without being connected at the same time, with no card ever promised twice.

## Requirements

- R1 (CAP-10; AD-8): a player has a random friend code (4 characters, a dash, 4 characters, never derived from a name) and a permanent invite link; an invitation by either becomes a friendship when accepted, and an ignored one creates nothing.
- R2 (CAP-11; AD-8): a proposal holds an offer and a request (at least one card per side, at most 4 different cards per side, a chosen quantity of each); the friend accepts, declines or counters, the proposer cancels, a proposal expires 7 days after it was sent or last countered.
- R3 (CAP-11; AD-6, AD-8): only the current offer is reserved, up to the copies owned minus those reserved elsewhere; requested cards are checked free at acceptance.
- R4 (CAP-11; AD-8, AD-10): acceptance swaps every card in one transaction; a declined or expired trade moves nothing and releases the cards; two friends have one open trade at a time; non-friends cannot trade.
- R5 (CAP-21; AD-24): a player sees each friend's presence and the friends menu counts those online.
- R6 (AD-13, AD-14, AD-16): the trade board is a React island over server-rendered card faces; trades and invitations reach the other player through a private stream; deleting or banning an account cancels its trades and drops its friendships.

## Done when

1. A valid invite link or friend code sends an invitation; once the other player accepts it, the friendship is visible to both. An ignored invitation creates nothing.
2. A player proposes a trade holding an offer and a request (at least one card each side, at most 4 different cards per side, a chosen quantity of each); the friend accepts, declines or answers with a counter-proposal that may change both sides; the proposer can cancel; a proposal expires after a fixed 7 days.
3. A card offered in an open trade cannot be offered in another until the trade ends: a player offers at most the copies they own minus those reserved elsewhere. Requested cards are not reserved; acceptance checks they are still free.
4. Acceptance swaps every card at once; an expired or declined trade moves nothing and releases the cards.
5. Two friends never have two open trades at the same time; non-friends cannot trade.
6. A player sees each friend's presence (online, current activity or last seen) and the friends menu shows how many are online.

## Boundaries

Friendships and trades in `Game`, the friends page and the trade board React island. Not live trades with both players connected (later).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-8, AD-16
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Key Flows (Flow 2), State Patterns

## Notes

- Amended (2026-10-09, change-profile-privacy): a private player cannot trade and a private friend's presence shows "profil privé", outside the online count; R4, R5 and Done when 5 and 6 read with that exception. Built by epic 7 (stories 20 and 21).
- Local commits named story 5.13 (before the 2026-10-09 reconciliation) are entry 5.14.
- Decision (2026-10-07): how two players become friends is the friend code and the permanent invite link of each player (one link per player, the same acceptance as a code); a signed-out visitor who opens a link signs in first and returns to it.
- Decision (2026-10-07): the friend code is purely random (for example 7K2Q-F3NX), never derived from a name; the UX examples (HUGO-7K2Q, KAI-8F2D) are replaced.
- Decision (2026-10-07): a trade draft lives in the browser, never in the database; no row exists until the proposal is sent, so a draft never blocks the friend.
- Decision (2026-10-07): a counter-proposal restarts the 7-day expiry.
- Decision (2026-10-07): the trade board island is split in two stories, the picker and quantities first, then the draft, the counter and the swap animation.
- Not built here: SIGNALER on a friend's profile waits for reports (epic 7); the window that counts as online is tuned in play (AD-24).
- The 2026-10-05 redesign changed CAP-10 (invitations) and CAP-11 (offer and request, quantities, fixed 7-day expiry); Description and Done when follow it. Friends' presence (CAP-21) belongs here (author, 2026-10-05; architecture AD-24).
