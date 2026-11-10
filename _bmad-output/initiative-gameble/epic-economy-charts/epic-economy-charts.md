---
tracker_id: ""
key: ""
type: epic
title: "Economy charts"
parent: initiative-gameble
covers: ["CAP-34", "CAP-36", "CAP-38"]
after: []
assignee: ""
risk: medium
estimate: ""
estimate_basis: ""
---

# Economy charts

## Description

The market's economy becomes visible in charts. A public page under the market, the Bourse de la Confrérie, shows the Reactor (PiCoins minted and destroyed per day, PiCoins in circulation) and what each rarity costs in days of capsules, with a price index. A card's detail shows its edition's recent sales. The back-office shows the four economy indicators as 90-day series with their thresholds. Every figure is computed on the server from the daily snapshot or the settled sales; Chart.js only draws it on a canvas, and every chart has a complete table. Each public chart stays hidden from players until an administrator publishes it. Published charts are served as versioned fragments that Cloudflare caches. The epic delivers only the chart part of CAP-34 and CAP-36; the figures it draws come from the market release.

## Outcome

For the players: they can see whether PiCoins pile up, what a card is worth in days of play and how an edition has been selling, before they sell or bid. For the author: the economy's health reads at a glance in the back-office, and nothing goes public before the data is worth showing.

## Requirements

- R1 — Every number a viewer reads comes from the server through `Game::Market::EconomySeries` or `Game::Market::EditionSales`; the browser only formats it with the shared number helpers. A missing figure is a gap and "—", never 0. (AD-51)
- R2 — One `ChartComponent` and one `chart` Stimulus controller draw every chart with Chart.js 4.6.1, loaded only on pages with a chart; one y-axis per chart. (AD-51, AD-16; DESIGN.md, Marché, Charts)
- R3 — The Bourse shows the Reactor: four headline figures, minted and destroyed per day over 30 days, PiCoins in circulation on a second chart. (CAP-38; EXPERIENCE.md, Bourse de la Confrérie)
- R4 — The Bourse shows each rarity's price in days of capsules as a tile with its 90-day trend, and a base-100 price index over 90 days with the rarities told apart by colour, shape and name. (CAP-38; EXPERIENCE.md, Bourse de la Confrérie)
- R5 — Each public chart (Reactor, rarity prices, edition chart) appears to players and visitors only once an administrator publishes it from the back-office; staff always see it, flagged; the Bourse and its link exist only while the Reactor or the rarity prices are published, never before the market's first opening, and stay while it is suspended. (CAP-38; AD-51; EXPERIENCE.md, Publication switch, Staff-only flag, Bourse de la Confrérie)
- R6 — A card's detail shows its edition's sales over the average-price window, the average after each sale and the rarity's minimum price, with its states (not published, few sales, no sale, staff). (CAP-34; AD-51; EXPERIENCE.md, Edition chart)
- R7 — The back-office shows the four indicators as 90-day series in small multiples with their thresholds or targets, prices in days of income one rarity at a time. (CAP-36; AD-48; EXPERIENCE.md, Marché, Back-office)
- R8 — Every chart has a summary sentence, a complete table of what it draws, spoken forms for compact figures and durations, a legend at small widths, a redraw in system colours under forced colours, and no animation under reduced motion. (EXPERIENCE.md, Chart and Accessibility Floor, Charts)
- R9 — A published chart is a signed-out, cookieless fragment at a versioned URL, cached for a year by Cloudflare and in `Rails.cache`; a new snapshot or sale makes a new URL; an unpublished or stale version answers not found. (AD-51, author 2026-11-10)

## Done when

1. With snapshots and sales on staging, an administrator publishes the Reactor and the rarity prices, and a visitor reads the Bourse from the market screen, with every figure and table matching the snapshot.
2. A card's detail shows its edition chart once published, in each of its states.
3. The back-office shows the four indicator series and the publication switches; moderators see the switches read-only.
4. A second request for a published chart is answered by Cloudflare without reaching Rails, and a new snapshot changes the URL.
5. Each chart passes the accessibility floor's chart rules: summary, complete table, keyboard, forced colours, reduced motion.
6. Shipped to production in release 1.3.x, with the charts the author chooses published.

## Boundaries

Prerequisites from the market release, built by its epics as the architecture states them: the daily snapshot with circulation, destroyed including forfeits, the median of positive earnings and `EditionPrice.rarity_average` (AD-47, AD-48); `average_after_sale` stored at settlement (AD-47); the single 00:10 nightly job (AD-50); `EconomySeries`' indicator series, read by the alerts (AD-48); the day-of-income targets as settings (AD-42). No new indicator and no automatic regulation. No time axis adapter. The later charts in `later-roadmap.md` (edition comparison, volume, top movers, collection value, a player's flows, Lorenz curve) are out. The page caches charts, never a page that carries the session.

## References

- spec — _bmad-output/initiative-gameble/spec-gameble/spec-gameble.md, CAP-34, CAP-36, CAP-38
- spec — _bmad-output/initiative-gameble/spec-gameble/market-economy.md, Charts and Indicators
- architecture — _bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md, AD-47, AD-48, AD-50, AD-51
- design — _bmad-output/initiative-gameble/ux-gameble/DESIGN.md, Marché, Charts; Chart colours
- experience — _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md, Marché (Bourse de la Confrérie, Edition chart, Chart, Publication switch, Staff-only flag, Back-office), Accessibility Floor (Charts), Flow 10
- mockup — _bmad-output/initiative-gameble/ux-gameble/mockups/market-charts.html

## Notes

- Decision (2026-11-10, author): built after the market release (CAP-29 to CAP-37), epics 38 to 41; its `after` in the initiative's breakdown names what it needs from each.
- Decision (2026-11-10, author): charts are published by hand, one switch per public chart, no numeric threshold.
- Decision (2026-11-10, author): charts are cached as much as possible, by Cloudflare or the server.
- Decision (2026-11-10, author): the market's epics own the snapshot, `average_after_sale`, the nightly job, `EconomySeries`' indicator series and the day-of-income settings, since AD-47, AD-48 and AD-50 already state them; this epic only extends `EconomySeries` with the Reactor and the rarity prices and draws the charts.
- Decision (2026-11-10): the tracer is story 1, the Reactor for staff, through every layer; publication and caching (2, 3) come before the other panels so each later chart is born published-aware and cached; the back-office series (6) follow the edition chart (5), which owns the dashed flat series both use.
- Decision (2026-11-10): the rarity tiles' sparklines cover 90 days, like the series they come from; EXPERIENCE.md's Bourse row was corrected from 30 days.
- Decision (2026-11-10, author): release 1.3.x, after the market opens.
