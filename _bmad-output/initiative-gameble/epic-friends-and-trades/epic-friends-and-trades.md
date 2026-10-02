---
tracker_id: ""
key: ""
type: epic
title: "Friends and trades"
parent: initiative-gameble
covers: [CAP-10, CAP-11]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Friends and trades

## Description

Players become friends through an invite link or a friend code, and trade cards on a face-to-face board, asynchronously, with counter-proposals. Cards placed in a trade are reserved.

## Outcome

For two friends: swapping cards without being connected at the same time, with no card ever promised twice.

## Requirements

Completed at this epic's inception. The source lines are CAP-10 and CAP-11 of the spec.

## Done when

1. A valid invite link or friend code creates a mutual friendship visible to both players.
2. A player proposes a trade; the friend accepts, declines or answers with a counter-proposal; the proposer can cancel.
3. A card placed in an open trade cannot be placed in another until the trade ends.
4. Acceptance swaps every card at once; an expired or declined trade moves nothing and releases the cards.
5. Two friends never have two open trades at the same time; non-friends cannot trade.

## Boundaries

Friendships and trades in `Game`, the friends page and the trade board React island. Not live trades with both players connected (later).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, section Capabilities
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-8, AD-16
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Key Flows (Flow 2), State Patterns

## Notes

- Unknown: no flow narrates how two players become friends; the UX review flagged it. Settled at this epic's inception.
