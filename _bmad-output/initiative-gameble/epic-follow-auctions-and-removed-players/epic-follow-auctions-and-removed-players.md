---
tracker_id: ""
key: ""
type: epic
title: "Following one's auctions, and removed players"
parent: initiative-gameble
covers: ["CAP-31", "CAP-33"]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Following one's auctions, and removed players

## Description

The market keeps players informed and stays clean. An outbid player is told at once, on the page and in the bell; the Annonce refreshes live while open; a sale worth noticing appears in the feed; the market screen gets its filters and search. A banned or deleted player leaves the market: their listings are withdrawn, their leading bids voided and released, a deleted player's balance is forfeited, and the data export and deletion cover the market.

## Outcome

For the players: they never miss being outbid, and they see the market move. For the author: removing an account never leaves a card or PiCoins stuck.

## Requirements

The spec's capabilities CAP-31, CAP-33, CAP-14, CAP-15 and `market-economy.md` are the requirement source; inception lifts their lines into ids here.

## Done when

1. On staging, an outbid player sees the notice on the Annonce and a bell line, and the Annonce they have open refreshes when another player bids.
2. An Epic or Legendary sale, or one over the feed threshold, shows in the feed under VENTES, never in a ticker.
3. The market screen filters by rarity, set, genre, season and price, and searches by game.
4. Banning a seller withdraws their listings; banning or deleting a leader voids their bid and the auction resumes; a deleted player's balance is forfeited and the ledger still reconciles; the export lists their wallet, entries, listings and bids.
5. Shipped to production with the market closed.

## Boundaries

No new auction rule. The notices beyond the outbid one stay as the UX sets them.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-31, CAP-33, CAP-14, CAP-15
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-13, AD-14, AD-46, AD-49, AD-50 (DropPresenceJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Market events, Bid result, Feed entry, Names, Market screen; State Patterns, Market
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Needs from epic 39: listings, bids, `AuctionSold`, `BidPlaced`, the Annonce and the market screen.
- Touch points: the `game_feed_entries` kind check gains `sale` (expand then validate); `FeedEntries.visible`, `NewFeedEntries` and `VisibleFeedEntry`; `Game::ReleasePlayer`; the data export.
