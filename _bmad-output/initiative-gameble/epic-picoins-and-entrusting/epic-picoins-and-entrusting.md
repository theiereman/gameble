---
tracker_id: ""
key: ""
type: epic
title: "PiCoins and entrusting"
parent: initiative-gameble
covers: ["CAP-29", "CAP-35"]
after: []
assignee: ""
risk: high
estimate: ""
estimate_basis: ""
---

# PiCoins and entrusting

## Description

Players can turn cards into PiCoins. A player entrusts copies to the Brotherhood's Archives from a card's detail or the Confier screen, in one batch within the daily cap, and receives PiCoins minted by the 100-6-Tron into a wallet split into available and committed. Every PiCoin movement is an insert-only ledger entry, reconciled every night. Administrators change every economy setting from the back-office as a new version announced by the Brotherhood, and can open or close the market. Production runs with the market closed behind the teaser.

## Outcome

For the players: their spare copies become a currency that will buy cards at auction. For the author: every value of the economy can be tuned without a deployment, and every PiCoin is accounted for.

## Requirements

The spec's capabilities CAP-29, CAP-35 and `market-economy.md` are the requirement source; inception lifts their lines into ids here.

## Done when

1. On staging, after an administrator opens the market, a player entrusts a batch from a card's detail and from the Confier screen; copies over the daily cap stay in the collection and the screen says so; the balance shows available and committed.
2. The ledger reconciles against every wallet each night, and a deliberate mismatch is reported to the error tracker.
3. An administrator changes a setting within its bounds with the Brotherhood's announcement in both languages; a form drawn before the change is refused without charging anything.
4. An administrator opens and closes the market; while closed, entrusting is refused; the teaser stays at the market's address whatever the state.
5. Shipped to production with the market closed.

## Boundaries

No listing, bid, price or indicator. The market screen and the switch from teaser to market belong to epic 39. Every column of `game_market_settings` (amounts, minimums, cap, durations, increment, soft close, commission, average-price window, feed threshold, unusual-maximum threshold, alert thresholds and day-of-income targets) is created here so later epics only read it.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-29, CAP-35
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-6, AD-10, AD-40, AD-41, AD-42, AD-43, AD-50 (first closed version at deploy, OpenMarket, closing, ArchiveStocksJob, ReconcileWalletsJob)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Confier, Confier result, Balance chip, Settings behind an open form, Back-office; Flow 8
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Contract with epic 41: this epic creates `ReconcileWalletsJob` at 00:10 UTC in `config/recurring.yml` running the reconciliation only; epic 41 adds the edition price refresh then `WriteDailySnapshot`, in that order, in the same job.
- Contract with epic 39: this epic extracts `AcceptTrade#move` for entrusting; epic 39 reuses it at settlement.
- Contract with epics 39 to 41: this epic builds the one component that draws a PiCoin amount (compact and exact, with its accessible text) and the client `picoins` helper.
- Contract with epic 39: this epic records the first opening on the settings version; epic 39 switches the market address from the teaser to the market screen once it exists.
- The Balance chip stays hidden until the first opening (State Patterns, Market not yet open).
