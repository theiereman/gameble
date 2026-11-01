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

From the missing cards of a player's active goals, the game finds the friends who hold spare copies, puts first the trades where each side gives the other a card it needs, and shows at most three suggestions at the top of the Échanges screen, each sent as it stands or opened on the trade board. The Brotherhood presents itself as the go-between. Two friends may now hold any number of open trades, so a suggestion never waits behind one. Release 1.1.0, from GitHub issue #64 (its second part), kept by the author on 2026-10-30, who expects it to need much work and testing.

## Outcome

For players working on goals: trading, not only opening packs, moves them forward; the signal is trades started from a suggestion and accepted.

## Requirements

Completed at inception. The lines from the source:

- E1 (CAP-11). For the missing cards of a player's active goals, the game lists the friends who own a spare copy (a copy beyond the one they keep, and not reserved in a trade).
- E2 (CAP-11). Mutual suggestions come first: the friend has a card the player needs, and the player has a spare the friend needs for their own goals.
- E3 (CAP-11). A suggestion starts a trade proposal with its cards already placed, under the trade rules of CAP-11.
- E4 (CAP-8, CAP-11). A private player, or one whose profile hides from the player, is never suggested and never sees suggestions naming others.
- E5 (CAP-11). Two friends may hold any number of open trades at once; a proposal identical to one already open between them is refused (author, 2026-10-31).

## Done when

1. A player with an active goal sees, in English and French, which friends hold a spare of each missing card.
2. A suggestion where both sides need what the other spares is shown before the one-sided ones.
3. Starting a trade from a suggestion opens the proposal with its cards placed, and the trade then runs as any other.
4. No suggestion ever names a private player or reveals a collection its owner hides.
5. Two friends hold two open trades at once, each reserving only its own offer, and a repeated send creates no second trade.
6. Release 1.1.0 or the release carrying the suggestions is on production.

## Boundaries

Suggestions among friends, on the trade side. Not suggestions beyond friends (#64 names them as a later extension, with privacy controls), not active goals themselves (epic-aim-at-the-cards-you-want), not targeted boosters.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-8, CAP-11 and CAP-28
- input — https://github.com/theiereman/gameble/issues/64, part 2, with the author's comment
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-8, AD-10 and AD-38
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Échanges; mockup _bmad-output/initiative-gameble/ux-gameble/mockups/trade-suggestions.html

## Notes

- Waits on epic-aim-at-the-cards-you-want because: suggestions are computed from the active goals and their missing cards.
- Decision (2026-10-30, author): its own epic, so that 1.1.0 can ship with the goals alone if suggestions slip.
- Decision (2026-11-01, author): "spare" is AD-38's rule: a free copy beyond the one its holder keeps, never a game in an open trade between the pair; a goal misses only games its holder has none of, so a spare never serves the holder's own goals. Closes the open question.
- Decision (2026-11-01, author): the suggestions read stays under 200 ms of server time on a seeded worst case of 100 friends, each with 5 goals of 50-game sets, and its query count does not grow with friends (entry 3); past it, `bmad-architecture` designs AD-38's deferred cache before entry 3 ships.
- Decision (2026-11-01, author): the design (entry 1) is done in `ux-gameble` on 2026-10-31: a SUGGESTIONS section of at most 3 rows in the Échanges screen, hidden when empty, never dismissable; goal bookmarks on every trade board (entry 9); ÉCHANGE opens the friend's new-proposal draft.
- Decision (2026-11-01, author): two friends may hold any number of open trades (spec CAP-11, AD-8); entry 8 lifts the limit first, since a suggestion must never wait behind an open trade.
- Decision (2026-11-01, author): entry 5, a goal's line leading to its suggestions, is dropped: suggestions live only in the Échanges screen. Entry 7, the end-to-end suite, is kept.
- Decision (2026-11-01, author): the outcome signal (trades started from a suggestion and accepted) is not recorded, to keep a column out of this epic; it is read from accepted trades between friends with goals.
- Decision (2026-11-01): tracer bullet entry 2 (one-sided suggestions through the query, the Échanges screen and the send); entries 3 and 4 run in parallel after it; entry 8 has no prerequisite and can start before epic 28 ends.
