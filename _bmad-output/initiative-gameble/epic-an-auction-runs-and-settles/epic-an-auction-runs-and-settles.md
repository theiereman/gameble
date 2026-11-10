---
tracker_id: ""
key: ""
type: epic
title: "An auction runs and settles"
parent: initiative-gameble
covers: ["CAP-30", "CAP-31", "CAP-32", "CAP-33"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# An auction runs and settles

## Description

Players sell and buy cards at auction. A seller lists an unreserved copy with a stamp, a duration and an optional buy-now price; bidders state a maximum held in escrow; the displayed price follows the second-highest maximum; a late bid extends the auction; a job closes each due auction and settles it exactly once: the winner gets the copy and the surplus, the seller the price less the commission, which is destroyed. The settlement also refreshes the edition's average price and stores it on the sold listing. The market screen, the Annonce with its bid history, MES ENCHÈRES and MES VENTES let players follow it.

## Outcome

For the players: a card they want can be won at auction without overpaying, and a card they sell pays them without them coming back. For the author: no PiCoin or copy ever moves twice.

## Requirements

The spec's capabilities CAP-30, CAP-31, CAP-32, CAP-33 and `market-economy.md` are the requirement source; inception lifts their lines into ids here.

## Done when

1. On staging, a player lists a copy, two players bid, the leader is outbid by a higher maximum, a bid in the last 3 minutes extends the auction, and at close the winner holds the copy with the surplus returned and the seller holds the price less the commission.
2. A maximum reaching the buy-now price buys at once; an auction with no bid returns the copy and can be relisted in one action; a seller cancels while no bid stands.
3. Running the close twice or bidding at the close never moves a PiCoin or a copy twice, and the ledger still reconciles.
4. Once the market has opened, its address shows the market screen; a closed market shows the suspended banner above readable listings.
5. Shipped to production with the market closed.

## Boundaries

No outbid notice, bell line, live refresh of the Annonce, sale feed entry, market filters or search, and no handling of banned or deleted players: epic 40. No price display, sort or indicator: epic 41, which fills the average price facts this epic lays out on the Annonce and Mettre en vente.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-30, CAP-31, CAP-32, CAP-33
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-8, AD-10, AD-44, AD-45, AD-47 (table, EditionPrice, upsert at settlement, average_after_sale), AD-49, AD-50 (CloseDueAuctionsJob, CheckMarketHealthJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Market screen, Listing tile, Annonce, My maximum form, Unusual maximum dialog, Buy-now, Bid result, History row, Names, Mettre en vente, MES ENCHÈRES row, MES VENTES row; Flow 7
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Needs from epic 38: wallets and `Ledger.post`, settings versions, the open state and the first opening, `AcceptTrade#move`, the PiCoin amount component.
- Contract with epic 41: this epic lays out the average price facts on the Annonce and Mettre en vente; epic 41 fills them. It produces the age of the oldest due listing (`CheckMarketHealthJob`), which epic 41's health page shows.
- Touch points: the settlement receives the winner's allocation, records set tiers with `reached_by: "trade"` and removes unheld showcase entries (AD-10, AD-45); `AuctionSold` reaches `GoalsReached` and `Achievements`, never `WeeklyContribution`; `config/recurring.yml`.
