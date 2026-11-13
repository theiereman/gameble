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

- R1 — Each card's average sale price is computed per exact edition (game + season) from the last 5 sales of the last 90 days, the highest and lowest dropped; under 3 sales it shows with "peu de ventes"; with no sale in the window it shows "Sans vente"; the sale count and the window are settings. (CAP-34; market-economy.md, Average price; AD-47)
- R2 — The card detail's facts show "Prix moyen" with the season for the edition of the published season, and ÉDITIONS gives each owned edition's price, in the same states, for players and visitors alike; the card face never carries a price. (CAP-34; EXPERIENCE.md, Card detail and the market, Copy deck Average price; DESIGN.md, Marché, Average price)
- R3 — The seller sees the chosen edition's average price when listing, and the Annonce shows it with "Fondé sur <n> ventes". (CAP-34; EXPERIENCE.md, Mettre en vente, Annonce, Copy deck Annonce)
- R4 — Toutes les cartes and a player's collection sort by "prix moyen" ascending or descending and filter by a price range (the PRIX group, "Prix minimum" and "Prix maximum"), joining the edition price table; the price of the published season's edition, or of the player's most valuable copy in their collection, shows under each card only when sorted or filtered by price and ends the card's accessible name; cards with no sale come last in both directions. (CAP-34; AD-47; EXPERIENCE.md, Sort and filter by price; DESIGN.md, Marché, Average price)
- R5 — Until the market's first opening there is no price, no price sort and no price filter anywhere. (EXPERIENCE.md, State Patterns, Market not yet open)
- R6 — A nightly refresh brings the edition price rows whose window moved up to date through `Game::Market::EditionPrice`, the only formula. (AD-47)
- R7 — A rarity's average price is the median of the averages of that rarity's edition rows with at least the minimum sale count, null when there is none, computed only by `Game::Market::EditionPrice.rarity_average`. (AD-47; market-economy.md, Charts, Rarity price)
- R8 — `ReconcileWalletsJob`, every day at 00:10 UTC, runs the reconciliation, the edition price refresh, then `WriteDailySnapshot`, in that order in one job. (AD-50)
- R9 — `Game::Market::WriteDailySnapshot` writes one `game_market_daily_snapshots` row per UTC day: PiCoins created, destroyed (stamps, commissions and forfeits, forfeits also stored apart), circulation at the end of the day, PiCoins per player active over 90 days, the median daily earnings, each rarity's average price, the top 1% share and the reconciliation result; it publishes `Game::Market::DailySnapshotWritten`; a second run for the same day changes nothing; days before the first opening have no row. (AD-48; market-economy.md, Charts, Destroyed)
- R10 — Circulation at the end of a day is the sum of every entry's deltas before the next UTC midnight, read in the reconciliation's `REPEATABLE READ` snapshot; each day's circulation equals the previous day's plus created less destroyed. (AD-48)
- R11 — An active player opened a pack in the period; earnings are `mint` plus `sale` less `commission`; the median daily earnings is the median over the players active that day whose earnings are positive, null when there is none. (AD-48; market-economy.md, Charts, A standard player's daily income)
- R12 — `Game::Market::EconomySeries`, a query on the reading role, is the only reader of the snapshots and returns the four indicators over 90 days ending on the last complete UTC day: destroyed against created over 30 days, PiCoins per active player, prices in days of income per rarity (`price.fdiv(median)`, null when either is null, computed only here) and the top 1% share, each threshold or target as the current version's value in a flat `threshold` series; a missing figure is null, never 0. (AD-48; AD-51; market-economy.md, Indicators)
- R13 — The back-office computes the four indicators automatically; each gives its value and says in plain language what is happening, why it matters and what to do, or "Pas encore assez de données" before it can be read. (CAP-36; AD-18; EXPERIENCE.md, Back-office)
- R14 — The health page shows the last reconciliation, the day's snapshot and the age of the oldest listing due to close. (EXPERIENCE.md, Back-office; AD-50)
- R15 — An alert is derived from an indicator's last point and the current thresholds and proposes an action: "Préparer ce changement" prefills every value the change requires in the settings form (a raised stamp brings the raised minimum with it) and moves focus to the first changed field; "Ignorer" hides that alert until its value changes; nothing changes until an administrator saves; there is no automatic regulation. (CAP-36; AD-48; EXPERIENCE.md, Back-office; Flow 9)
- R16 — `Game::Market::RefreshAltSignals` replaces `game_market_alt_signals` every day at 00:40 UTC, one row per account and signal with the facts behind it, for the five signals: near-maximum capsule opening, repeated one-way trades, sales outside market price between the same accounts, repeated minimum-price sales between the same two accounts, bids on a listing from an account tied to its seller; thresholds are constants of `Game::Market::AltSignals`. (AD-48; AD-50; market-economy.md, Alt-account signals)
- R17 — The back-office lists the accounts matching the signals with the facts behind each and a link to the account; the rows are staff data read only there; detection changes nothing on the account, limits no trade and adds no seniority gate; staff act through the existing ban. (CAP-37; AD-48; EXPERIENCE.md, Back-office)
- R18 — The terms of use forbid trading cards and PiCoins for real money, and say PiCoins are never bought or withdrawn. (spec, Constraints, No real money, Before the market opens)
- R19 — The privacy and retention pages name the market's data: the wallet, the PiCoin entries, listings and bids with the player's own maximums, and what deletion keeps without identity. (spec, Constraints, Market and personal data; AD-46)
- R20 — The market opens in production only after it is exercised closed on staging, through `Game::Market::OpenMarket`, which records the confirmation that the terms forbid real-money trading and that the draw odds are published. (AD-50; spec, Constraints, Before the market opens)
- R21 — Each card of a trade, on the trade board in every state and in its card picker, shows its edition's average price centred under it, or "Sans vente", and nothing more: no few-sales mention, no total per side, one copy's price for a stack; the price ends the card's accessible name. (CAP-34; EXPERIENCE.md, Échanges, Trade board and Card picker; mockups/trade-average-price.html)

## Done when

1. Each card's detail shows its edition's average price, with the few-sales and no-sale cases; the collection sorts and filters by price; Mettre en vente, the Annonce and the trade board show it.
2. The health page shows each indicator with what is happening, why it matters and what to do, the last reconciliation, the day's snapshot and the oldest due listing; an alert prefills a settings change that applies only once saved.
3. The back-office lists accounts matching the alt-account signals with their facts, and changes nothing on them.
4. The terms forbid trading cards or PiCoins for real money, and the privacy and retention pages name the market's data.
5. The market is open in production, after the staging exercise.

## Boundaries

Not the indicator charts, the Reactor, the rarity-price series or any chart: epic 37 (this epic builds `EconomySeries`' four indicator series, which epic 37 draws). No automatic regulation.

## References

- parent — _bmad-output/initiative-gameble/initiative-gameble.md
- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-34, CAP-36, CAP-37
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-47 (nightly refresh, rarity_average), AD-48, AD-50 (the full 00:10 job, rollout and opening)
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché, Average price, Sort and filter by price, Card detail and the market, Back-office; State Patterns, Market not yet open; Flow 9
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché
- mockups — _bmad-output/initiative-gameble/ux-gameble/mockups/market-options.html, _bmad-output/initiative-gameble/ux-gameble/mockups/market-screens.html, _bmad-output/initiative-gameble/ux-gameble/mockups/trade-average-price.html

## Notes

- Decision (2026-11-10, author): epics 38 to 40 ship to production with the market closed behind the teaser; the first opening is the final hitl story of epic 41, so daily snapshots start on day one.
- Owns CAP-34 except the edition chart line and CAP-36 except the 90-day series line, both epic 37's.
- Needs from epic 38: settings with thresholds and targets, `ChangeSettings`, `ReconcileWalletsJob` (this epic adds the price refresh then `WriteDailySnapshot` to it), the ledger. From epic 39: settled listings, `EditionPrice` and the edition price table, the average price facts laid out on the Annonce and Mettre en vente, the oldest due listing's age. From epic 40: forfeits, for the destroyed figure.
- Builds `Game::Market::EconomySeries` with the four indicators, read by the alerts; epic 37 extends it.
- The capsule odds are already published (`app/views/pages/_odds_table.html.erb`); the opening story checks them.
- Touch points: the legal page and the privacy and retention pages; the collection screens.
- Decision (2026-11-10): the tracer is story 1, the card detail's average price kept current by the edition price refresh inside `ReconcileWalletsJob`: job, operation, table, query and screen in one path. The daily snapshot (2), the slice least settled, follows it; the price surfaces (3, 4) and the snapshot lane (5, 6) then run apart.
- Decision (2026-11-10): the health page (5) owns the back-office market navigation entries for this epic; the signals (7) wait on it so the two never edit that navigation at once.
- Decision (2026-11-10): `config/locales/en.yml` and `fr.yml` take additive edits to distinct key subtrees from stories with no dependency path between them (3, 4, 5 to 8, 9); a merge conflict there is resolved by keeping both sides.
- Decision (2026-11-10): story 4 reuses the PRIX group built by epic 40's story 7 and waits for it; story 1 shows the sale count under Prix moyen; story 9 adds the market section of Comment ça marche; story 11 is also the staging exercise of epics 39 and 40.
- Decision (2026-11-10): the opening (11) comes after the refactor sweep (10), since it opens production on the finished code; the sweep is after every other story.
- Decision (2026-11-10): high-risk checks outside the stories' own tests: for 2, the author confirms on staging that the first snapshots' circulation chains and matches the reconciliation's global sum; for 11, the author's staging exercise is the check.
- Decision (2026-11-10): the "minimum sale count" of AD-47 and AD-51 is the few-sales threshold, 3, a constant of `EditionPrice`, not a setting (epic 38 has no such column); an edition under it shows "peu de ventes", stays out of `rarity_average` and draws no average in epic 37's edition chart.
- Decision (2026-11-10): the edition price refresh and `RefreshAltSignals` are housekeeping `ApplicationOperation`s with no event, as `Game::SumWeeklyGoal` is; it recomputes every row with sales used, one row per transaction under the row's lock, which covers a moved window and a changed window setting.
- Decision (2026-11-13, author): trades and the market stay side by side; trades stay card for card, with no PiCoins and no fee. To let friends judge a trade, each card of a trade shows its edition's average price (story 12, R21): the bare price or "Sans vente", no total, no few-sales mention, on concluded trades too, at today's price.
- Assumption: the snapshot is written even when the reconciliation finds a difference, carrying that result; the health page's last reconciliation reads the latest snapshot.
- Assumption: the top 1% share is the share of all PiCoins (available plus committed) held by the richest 1% of wallets holding any, rounded up to at least one wallet.
- Assumption: an indicator shows "Pas encore assez de données" when its last point is null or no snapshot exists yet; such an indicator raises no alert.
- Assumption: "Ignorer" is kept in the administrator's browser, keyed by the indicator and its value, so the health page's GET writes nothing.
- Assumption: the health page is open to staff; "Préparer ce changement" shows for administrators only, as `ChangeSettings` is theirs.
- Assumption: the optional typical price per rarity of `market-economy.md` (Average price) is not shown to players at launch.
- Open question: which change the destroyed-against-created alert proposes. Flow 9 shows the Rare stamp from 2,000 to 3,000 with its minimum to the no-loss floor of 8,900; the story assumes every rarity's stamp raised by half, rounded up to the hundred and capped by the double-or-halve bound, each minimum lifted to its no-loss floor, until the author says otherwise.
- Open question: the alt-signal thresholds and what ties an account to a seller. Story 7 and 8 assume near-maximum opening at 120 capsules or more a day on 3 of the last 7 days, one-way trades at 10 or more in 7 days with nothing received, sales outside market price at under half or over twice the edition's average, minimum-price sales at 3 or more in 30 days between the same pair, and "tied" as a pair already flagged by another pair signal in the same run; the author confirms or changes them when the story starts.
