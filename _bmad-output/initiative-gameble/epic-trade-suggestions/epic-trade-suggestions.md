---
tracker_id: ""
key: ""
type: epic
title: "Trade suggestions"
parent: initiative-gameble
covers: [CAP-11]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: "envelope"
---

# Trade suggestions

## Description

From the missing cards of a player's active goals, the game finds the friends who hold spare copies, puts first the trades where each side gives the other a card it needs, and opens the trade from the suggestion. The Brotherhood presents itself as the go-between. Release 1.1.0, from GitHub issue #64 (its second part), kept by the author on 2026-10-30, who expects it to need much work and testing.

## Outcome

For players working on goals: trading, not only opening packs, moves them forward; the signal is trades started from a suggestion and accepted.

## Requirements

Completed at inception. The lines from the source:

- E1 (CAP-11). For the missing cards of a player's active goals, the game lists the friends who own a spare copy (a copy beyond the one they keep, and not reserved in a trade).
- E2 (CAP-11). Mutual suggestions come first: the friend has a card the player needs, and the player has a spare the friend needs for their own goals.
- E3 (CAP-11). A suggestion starts a trade proposal with its cards already placed, under the trade rules of CAP-11.
- E4 (CAP-8, CAP-11). A private player, or one whose profile hides from the player, is never suggested and never sees suggestions naming others.

## Done when

1. A player with an active goal sees, in English and French, which friends hold a spare of each missing card.
2. A suggestion where both sides need what the other spares is shown before the one-sided ones.
3. Starting a trade from a suggestion opens the proposal with its cards placed, and the trade then runs as any other.
4. No suggestion ever names a private player or reveals a collection its owner hides.

## Boundaries

Suggestions among friends, on the trade side. Not suggestions beyond friends (#64 names them as a later extension, with privacy controls), not active goals themselves (epic-aim-at-the-cards-you-want), not targeted boosters.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-8, CAP-11 and CAP-28
- input — https://github.com/theiereman/gameble/issues/64, part 2, with the author's comment

## Notes

- Waits on epic-aim-at-the-cards-you-want because: suggestions are computed from the active goals and their missing cards.
- Decision (2026-10-30, author): its own epic, so that 1.1.0 can ship with the goals alone if suggestions slip.
- Open question: what a "spare" copy is when a friend's own goals need it; settled at inception.
- Unknown: the cost of computing mutual suggestions across friends' collections and goals; inception sizes it against the architecture's performance budget.
