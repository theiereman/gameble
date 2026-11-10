---
tracker_id: ""
key: ""
type: epic
title: "Prices, economy health and opening"
parent: initiative-gameble
covers: ["CAP-34", "CAP-36", "CAP-37"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# Prices, economy health and opening

## Description

The market gets its prices and its dashboard, then opens. Every card shows its edition's average price, the collection sorts and filters by it, and the seller sees it when listing. The back-office health page explains the four indicators in plain words, shows the last reconciliation, the day's snapshot and the oldest due listing, and turns an alert into a prefilled settings change that an administrator validates. It lists accounts matching the alt-account signals with their facts. The terms and the privacy and retention pages cover the market. Finally the author exercises the closed market on staging, checks the published capsule odds and the terms, and opens the market in production.

## Outcome

For the players: the market opens, and every card has a price to compare. For the author: the economy's health reads in plain words, and nothing changes without an administrator.

## Requirements

The spec's capabilities CAP-34, CAP-36, CAP-37 and `market-economy.md` are the requirement source; inception lifts their lines into ids here.

## Done when

1. Each card's detail shows its edition's average price, with the few-sales and no-sale cases; the collection sorts and filters by price; Mettre en vente and the Annonce show it.
2. The health page shows each indicator with what is happening, why it matters and what to do, the last reconciliation, the day's snapshot and the oldest due listing; an alert prefills a settings change that applies only once saved.
3. The back-office lists accounts matching the alt-account signals with their facts, and changes nothing on them.
4. The terms forbid trading cards or PiCoins for real money, and the privacy and retention pages name the market's data.
5. The market is open in production, after the staging exercise.

## Boundaries

Not the indicator series or any chart: epic 37. No automatic regulation.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-34, CAP-36, CAP-37
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-47 (nightly refresh, rarity_average), AD-48, AD-50 (the full 00:10 job, rollout and opening)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Average price, Sort and filter by price, Card detail and the market, Back-office; State Patterns, Market not yet open; Flow 9
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Owns CAP-34 except the edition chart line and CAP-36 except the 90-day series line, both epic 37's.
- Needs from epic 38: settings with thresholds and targets, `ChangeSettings`, `ReconcileWalletsJob` (this epic adds the price refresh then `WriteDailySnapshot` to it), the ledger. From epic 39: settled listings, `EditionPrice` and the edition price table, the average price facts laid out on the Annonce and Mettre en vente, the oldest due listing's age. From epic 40: forfeits, for the destroyed figure.
- Builds `Game::Market::EconomySeries` with the four indicators, read by the alerts; epic 37 extends it.
- The capsule odds are already published (`app/views/pages/_odds_table.html.erb`); the opening story checks them.
- Touch points: the legal page and the privacy and retention pages; the collection screens.
