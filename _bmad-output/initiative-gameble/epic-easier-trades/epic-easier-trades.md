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

A player starts a trade from the Trades tab by choosing a friend, and finds worthwhile cards in the picker through filters that compare the two collections, on a board that stays light and smooth with thousands of cards. The trading rules do not change: this is usability inside CAP-11, asked for by a player in GitHub issue 63 (points 1, 2 and 4).

## Outcome

For two friends with large collections, finding a mutually worthwhile trade takes a few taps instead of browsing every card.

## Requirements

- R1 (CAP-11; issue 63, point 1): from the Trades tab, with or without trades, a player starts a new trade by choosing a friend from a list showing each friend's presence; the friend row's trade button stays; the existing refusals (private profile, one open trade per pair, non-friends) still apply.
- R2 (CAP-11; issue 63, point 2): the picker filters a side against the other player's collection: on the friend's side, their duplicates (2 or more copies), cards missing from mine, cards we both own; on my side, my duplicates, cards missing from theirs, cards with at least one unreserved copy. They combine with each other (AND), with rarity (OR within rarities) and with title search, compare cards in the unit the collection shows, and never change what may be traded (a single copy can still be offered).
- R3 (CAP-11; issue 63, point 4): on the phone the picker's filters fold into a collapsible section that keeps the match count and the clear action in view; filters are kept when the picker is reopened during the same trade.
- R4 (CAP-11; issue 63, point 4): the trade board and its picker stay light and smooth on a phone with thousands of cards on both sides.

## Done when

1. From the Trades tab, empty or not, a player picks a friend and lands on the draft board; a private friend or one with an open trade is refused as today, and a player with no friend is led to the invitation.
2. In the picker, a player shows only Rare or Epic cards their friend owns in duplicate and they are missing, and the cards already placed stay placed.
3. At phone width the filters fold away with the match count and clear action still in view, and are found as left when the picker is reopened in the same trade.
4. With players holding thousands of distinct cards, the page weight of the trade pages is recorded before and after, and the picker opens, scrolls and filters within the threshold the measurement sets, at phone width.
5. Shipped to production.

## Boundaries

The Trades screen, the trade board island and its picker, `TradesHelper` and `TradesController`, reads through `Game` and `Catalog` queries. Not new trade rules or operations, not the open trade request (issue point 5), not season, set or genre filters or sorting (issue point 3).

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md, section Requirements
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-11
- source — https://github.com/theiereman/gameble/issues/63, points 1, 2 and 4
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-16
- design — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Key Flows (Flow 2)
- prior work — _bmad-output/initiative-gameble/plan-trade-picker-filters.md (title search, rarity chips, match count, clear action, no-match state, selection kept while filtering)
- deferred — _bmad-output/initiative-gameble/deferred-work.md, the TradeBoard island page weight item

## Notes

- Decision (2026-10-15): a new epic rather than reopening epic 5, which is done and retrospected.
- Decision (2026-10-15): the epic's Requirements cite issue 63 as their source; the spec is not updated, the work stays inside CAP-11 (author).
- Decision (2026-10-15): the cross-collection filters combine with AND, unlike the collection's state filters, which combine with OR; the issue's example (Rare or Epic, their duplicates, missing from mine) needs AND (author).
- Decision (2026-10-15): "missing" and "both own" compare cards in the unit the collection shows, so entry 2 waits on 13.15, which makes it one card per game across editions (author).
- Decision (2026-10-15): the issue's quick filters are the filter chips themselves, one tap each; no separate shortcut (author).
- Decision (2026-10-15): the issue's "make owned and available quantities more visible" is not planned; both are already shown on each picker card.
- Deferred (2026-10-15): issue point 3 (season, set and genre filters, sorting by rarity, title, copies or relevance).
- Not here: issue point 5, the open trade request ("let them choose what they want in return"), is a new trade mechanic sent to bmad-forge-idea first (author, 2026-10-15).
- Decision (2026-10-15): tracer bullet is entry 1; the least certain is entry 4; entries 1 and 2 run in parallel lanes, sharing only new keys under different locale namespaces.
- Waits on epic 5 because: the trades screen, the trade board island and its picker exist.
- Waits on epic 13 because: entry 2 compares in the unit 13.15 gives the collection.
