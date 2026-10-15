---
tracker_id: ""
key: ""
type: epic
title: "Trades easy to start and to fill"
parent: initiative-gameble
covers: [CAP-11]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Trades easy to start and to fill

## Description

A player starts a trade from the Trades tab by choosing a friend, finds worthwhile cards in the picker through filters that compare the two collections, on a board that stays light and smooth with thousands of cards, and can leave their own side empty for the friend to choose what they want in return. Asked for by a player in GitHub issue 63 (points 1, 2, 4 and 5); the open request changes CAP-11's rules, the rest is usability inside them.

## Outcome

For two friends with large collections, finding a mutually worthwhile trade takes a few taps instead of browsing every card.

## Requirements

- R1 (CAP-11; issue 63, point 1): from the Trades tab, with or without trades, a player starts a new trade by choosing a friend from a list showing each friend's presence; the friend row's trade button stays; the existing refusals (private profile, one open trade per pair, non-friends) still apply.
- R2 (CAP-11; issue 63, point 2): the picker filters a side against the other player's collection: on the friend's side, their duplicates (2 or more copies), cards missing from mine, cards we both own; on my side, my duplicates, cards missing from theirs, cards with at least one unreserved copy. They combine with each other (AND), with rarity (OR within rarities) and with title search, compare cards in the unit the collection shows, and never change what may be traded (a single copy can still be offered).
- R3 (CAP-11; issue 63, point 4): on the phone the picker's filters fold into a collapsible section that keeps the match count and the clear action in view; filters are kept when the picker is reopened during the same trade.
- R4 (CAP-11; issue 63, point 4): the trade board and its picker stay light and smooth on a phone with thousands of cards on both sides.
- R5 (CAP-11; issue 63, point 5): at every send, proposal or counter-proposal, the friend's side holds a card and the sender's own side may be empty, which asks the friend to choose what they want in return; nothing is reserved for an empty side; a trade with an empty side cannot be accepted, on the screen and by the server; no gift.

## Done when

1. From the Trades tab, empty or not, a player picks a friend and lands on the draft board; a private friend or one with an open trade is refused as today, and a player with no friend is led to the invitation.
2. In the picker, a player shows only Rare or Epic cards their friend owns in duplicate and they are missing, and the cards already placed stay placed.
3. At phone width the filters fold away with the match count and clear action still in view, and are found as left when the picker is reopened in the same trade.
4. With players holding thousands of distinct cards, the page weight of the trade pages is recorded before and after, and the picker opens, scrolls and filters within the threshold the measurement sets, at phone width.
5. A player sends a proposal with only the friend's side filled; the friend sees no ACCEPTER but the invitation to choose, picks a card from the player's collection and sends it back, and the player accepts; accepting an empty-sided trade from a stale tab or a hand-made request is refused and nothing moves.
6. Shipped to production.

## Boundaries

The Trades screen, the trade board island and its picker, `TradesHelper` and `TradesController`, reads through `Game` and `Catalog` queries, and the trade operations in `packs/game` for the open request. Not other new trade rules, not a note or a discussion on trades, not season, set or genre filters or sorting (issue point 3).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-11
- source — https://github.com/theiereman/gameble/issues/63, points 1, 2, 4 and 5
- forge — _bmad-output/initiative-gameble/forge-open-trade-request/forge-open-trade-request.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-8, AD-16
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Key Flows (Flow 2)
- prior work — _bmad-output/initiative-gameble/plan-trade-picker-filters.md (title search, rarity chips, match count, clear action, no-match state, selection kept while filtering)
- deferred — _bmad-output/initiative-gameble/deferred-work.md, the TradeBoard island page weight item

## Notes

- Decision (2026-10-15): a new epic rather than reopening epic 5, which is done and retrospected.
- Decision (2026-10-15): R1 to R4 cite issue 63 as their source with no spec change, as usability inside CAP-11 (author); R5 follows the CAP-11 update of the same day.
- Decision (2026-10-15): the cross-collection filters combine with AND, unlike the collection's state filters, which combine with OR; the issue's example (Rare or Epic, their duplicates, missing from mine) needs AND (author).
- Decision (2026-10-15): "missing" and "both own" compare cards in the unit the collection shows, so entry 2 waits on 13.15, which makes it one card per game across editions (author).
- Decision (2026-10-15): the issue's quick filters are the filter chips themselves, one tap each; no separate shortcut (author).
- Decision (2026-10-15): the issue's "make owned and available quantities more visible" is not planned; both are already shown on each picker card.
- Deferred (2026-10-15): issue point 3 (season, set and genre filters, sorting by rarity, title, copies or relevance).
- Decision (2026-10-15): issue point 5, the open trade request, joins this epic as entry 6 after bmad-forge-idea hardened it and the spec (CAP-11), the UX (EXPERIENCE.md) and the architecture (AD-8) took it in (author).
- Decision (2026-10-15): the open request's refusal copy, for accepting an empty-sided trade, is left to entry 6's build (author).
- Deferred (2026-10-15): the trade list summary's "first game +n" format (EXPERIENCE.md) is not implemented; entry 6 adds only "À choisir" for an empty side (author, deferred-work.md).
- Decision (2026-10-15): tracer bullet is entry 1; the least certain is entry 4; entries 1 and 6 run in parallel lanes, sharing only new keys under different locale namespaces; entry 2 waits on 6, both changing the trade board island.
- Waits on epic 5 because: the trades screen, the trade board island and its picker exist.
- Waits on epic 13 because: entry 2 compares in the unit 13.15 gives the collection.
