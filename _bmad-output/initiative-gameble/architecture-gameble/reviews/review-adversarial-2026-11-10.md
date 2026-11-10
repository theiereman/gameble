# Adversarial review: the economy charts (AD-51, amended AD-16, AD-48, Stack, Deferred)

Spine reviewed: `architecture-gameble.md` (updated 2026-11-10), working-tree delta against HEAD: AD-51 added, one sentence added to AD-16, "PiCoins in circulation" added to AD-48's snapshot, `chart.js` 4.6.1 in the Stack (exists on npm), "Later economy charts" in Deferred, AD-51 added to CAP-34 and CAP-36 in the map.

Read for context: AD-9 to AD-16, AD-18, AD-27, AD-30, AD-40 to AD-51, the Consistency Conventions, `AGENTS.md`, `spec-gameble/market-economy.md` (Average price, Indicators), CAP-34 and CAP-36 of `spec-gameble.md`, and the validated mockup `ux-gameble/.working/market-charts.html`. The market is not built, so no market code was checked. Existing code was read only where a rule meets it: `ApplicationController` (reading role, `refuse`), `Accounts::Player#staff?`, `BackOffice::DashboardPolicy` (moderator), `MarketPolicy`, the fr number format (`delimiter: " "`), `app/frontend/lib/i18n.ts` (`formatNumber`), the card routes (`cards/:slug/seasons/:number` is the edition page).

Method: for each pair of units one level down (the snapshot job, `EconomySeries`, `EditionSales`, the alert derivation, the public economy page, the card page's edition chart, the back-office indicators, the publication switch, `ChartComponent`, the `chart` controller), build each one to the letter of every AD and look for where they disagree. Then check AD-51 against the project rules of `AGENTS.md`. Nothing was run.

Severity: **critical** a literal build crashes or shows a wrong figure on a public page on the normal path; **high** the same figure reaches a viewer computed or formatted two ways, or a literal build breaks a project rule; **medium** a visible inconsistency or a rule two builders would settle differently, at bounded cost; **low** a wording gap two builders would probably settle alike.

**Verdict: the shape is right (one query per source, one component, one controller, one library, a table beside every canvas, a staff switch), but the figures themselves are under-defined. "Days of income" divides by a median that is zero on a normal day and truncates under integer division; the rarity "average price" has no formula; "destroyed" and "in circulation" each have two readings; and the edition chart's line cannot be guaranteed to end on the price printed above it. AD-51 prevents "a figure computed two ways", and in four places the spine still permits it. One critical, five high, ten medium, eight low.**

---

## What was attacked and holds

- **One renderer, one library.** `ChartComponent` + one `chart` controller + one pure module per kind under `app/frontend/lib/charts/` leaves no room for a second chart path in the normal case (sparklines are the exception, M7). AD-16's new sentence closes the "script builds markup" loophole for Chart.js: it draws only in a canvas.
- **GET never writes.** Every chart read is a query on the reading role; the only writes are `WriteDailySnapshot` (a job) and `PublishChart` / `UnpublishChart` (operations behind a POST). No chart surface needs a watermark or a lazy computation on GET.
- **No id in JSON.** The JSON is restricted to kind, labels and keyed series, "never a color, an id or a token". `EditionSales` returns only `sold_at`, `final_price` and the running average, nothing that names a listing or a player.
- **Packwerk.** `EconomySeries` and `EditionSales` live in `Game::Market`; `ChartComponent` and the controller in the web layer read them. No new dependency edge.
- **CSP.** A dynamic `import()` of a Vite chunk is `script-src 'self'`. Chart.js 4 no longer injects a stylesheet, and sets canvas sizes through the CSSOM, which `style-src` does not block.
- **One y-axis.** The rule matches the mockup's stacked Reactor, the four back-office small multiples and the scatter. No chart in the mockup needs a second axis.
- **Publication cannot be automatic.** One row per chart, written only by two administrator operations; nothing in the snapshot or the indicators flips it.

---

## Critical

### C1. "Days of income" is undefined on a normal day, and truncates under integer division

**Units:** `WriteDailySnapshot` (AD-48) and `EconomySeries` (AD-51).

AD-48 stores "the median daily earnings of players active that day", earnings being `mint + sale - commission`, and an active player being one who opened a pack. AD-51 divides each rarity's average price by it. A player who opens capsules but neither entrusts nor sells that day has earnings 0. Entrusting is optional, so on most days, and certainly in the first weeks, fewer than half of active players earn anything: the median is 0.

- Builder A follows the letter: `price / median` with both columns `bigint` (every amount in AD-41 is `bigint`). Ruby raises `ZeroDivisionError`: the public economy page and the back-office indicators answer 500 on the first quiet day.
- Builder B guards the zero and uses integer division on the other days: a Common at 3,000 against a median of 1,000,000 is `0` days, so the Common, Uncommon and Rare lines of the public chart sit flat on zero (the mockup expects 0.003, 0.006, 0.13).
- Builder C computes the median over active players with positive earnings only; their series differs from A's and B's by orders of magnitude.

The spec's measure is "a standard player's income" (40 to 50 capsules a day); the mockup copy says "revenu médian des joueurs actifs". Neither matches a median that counts non-earners.

**Fix (AD-48, second bullet):** "An active player opened a pack in the period, read from `game_packs.opened_at`. Earnings are `mint` plus `sale` less `commission`. The day's median daily earnings is the median over the players active that day whose earnings are positive; it is null when there is none. A price in days of income is `price.fdiv(median)`, null when either is null, computed once by `Game::Market::EconomySeries` (alerts included, H2)."
**Fix (AD-51, after the first bullet):** "A missing figure is `null` in the JSON and a gap in the chart, never 0; the table prints the locale's no-value mark."

---

## High

### H1. The rarity "average price" has no formula, and the snapshot reads edition prices before they are refreshed

**Units:** `WriteDailySnapshot` (writes "each rarity's average price") and any later "typical price per rarity" (Deferred, set by the UX).

AD-47 makes `EditionPrice` the only formula, per edition. A per-rarity figure is a second formula the spine never states. Two literal builds:

- A: mean of `game_market_edition_prices.average` over the rarity's editions that have a row (each edition counts once, a 1-sale edition weighs as much as a 50-sale one).
- B: mean of `final_price` of the rarity's sales settled that day (null on days with no Legendary sale: the Legendary index is mostly gaps, and with 9 Legendary sales in the mockup's switch screen that is most days).

Both obey every AD; the index and days-of-income charts differ by a large factor between them. Add the schedule: `WriteDailySnapshot` runs at 00:10 UTC, `RefreshEditionPricesJob` at 00:30 (AD-50), so build A reads rows whose window has not yet moved: yesterday's averages, stamped as today's.

**Fix (AD-47, appended):** "A rarity's average price is the median of the `average` of that rarity's edition price rows with at least the minimum sale count, null when there is none, computed only by `Game::Market::EditionPrice.rarity_average`; the snapshot and any typical price per rarity read it."
**Fix (AD-50, table):** move `WriteDailySnapshot` after `RefreshEditionPricesJob` (one 00:10 entry running reconciliation, then edition prices, then the snapshot, see H3), or state that the snapshot reads prices only through `rarity_average` after the refresh.

### H2. "Destroyed" and the 30-day ratio are each computed in two places

**Units:** the public Reactor (AD-51: "destroyed counting stamps, commissions and forfeits"), the back-office indicator "PiCoins destroyed against created, 30 days" (AD-48, `market-economy.md`), the alert derivation (AD-48: "derived from a snapshot and the current thresholds"), and the public hero figures (mockup: EN CIRCULATION, FRAPPÉS · 30 J, DÉTRUITS · 30 J, DÉTRUITS / FRAPPÉS 56 %).

- AD-48's snapshot stores "created, destroyed and forfeited" as three figures, which reads as `destroyed` excluding forfeits. AD-51's Reactor folds forfeits into destroyed. The back-office indicator builder reads the `destroyed` column; the Reactor builder adds `forfeited`. The public "56 %" and the back-office "54 %" disagree on the same day.
- AD-51 makes `EconomySeries` "the only reader of `game_market_daily_snapshots` for charts". The alert is not a chart, so the alert derivation reads snapshots itself and computes its own 30-day ratio. The alert fires at 39 % while the chart beside it shows 41 %.
- The hero figures are not charts. Nothing says who sums 30 days: the controller, the view, or `EconomySeries`. A web-layer sum is a third computation.

**Fix (AD-48, first bullet):** "... PiCoins created (`mint`), destroyed (stamps, commissions and forfeits, with forfeits also stored apart) ..." so the column carries the same meaning everywhere.
**Fix (AD-51, second bullet):** "`Game::Market::EconomySeries`, a query on the reading role, is the only reader of `game_market_daily_snapshots`, for charts, figures and alerts alike. It returns the series below and their summaries (the last circulation, the 30-day sums and the 30-day destroyed-to-created ratio); the alert derivation reads its indicator series' last point, and no page sums snapshot rows itself."

### H3. "In circulation at the end of the day" is read at 00:10, from a sum the snapshot cannot reach

**Units:** `ReconcileWalletsJob` and `WriteDailySnapshot`, both at 00:10 UTC (AD-50).

AD-48 now stores "PiCoins in circulation at the end of the day (the reconciliation's global sum)". The reconciliation runs at 00:10 and sums the ledger at that moment, so its sum includes ten minutes of the new day: `circulation(d) - circulation(d-1)` no longer equals `created(d) - destroyed(d)`, and the Reactor's bars and its circulation line visibly disagree. Second, the reconciliation stores nothing but a report, so "the reconciliation's global sum" can reach the snapshot only by a handoff the spine does not define:

- A: two recurring entries; the snapshot recomputes the sum itself (a second computation, at another instant).
- B: the reconciliation job calls the snapshot with its result.

Recurring entries cannot be chained in `config/recurring.yml`, so "then" in AD-50's table is not enforceable as two entries.

**Fix (AD-48, first bullet):** "PiCoins in circulation at the end of the day: the sum of every entry's deltas with a time before the next UTC midnight, read in the reconciliation's `REPEATABLE READ` snapshot and handed to the snapshot operation by `ReconcileWalletsJob`, which runs it last. A test checks that each day's circulation equals the previous day's plus created less destroyed."
**Fix (AD-50, table):** one entry, `ReconcileWalletsJob` (reconciliation, then `WriteDailySnapshot`), every day at 00:10 UTC.

### H4. The edition chart's line cannot be guaranteed to end on the price printed above it

**Units:** the card page's price (the `game_market_edition_prices` row, AD-47) and `EditionSales`' `average` series (AD-51).

"At each sale, the average `EditionPrice` gives over the sales up to it" leaves three choices open:

- **Anchor of the window.** Up to the sale and within the window ending at the sale, or within the current window ending now? The row is anchored at its last refresh. With a last sale 80 days ago and a 90-day window, the line's last point counts sales up to 170 days old, the row only those of the last 90: the line ends on one number, the price above it shows another.
- **Settings version.** AD-42 has the window and sale count read from the current version. The mockup says the line shows "le prix moyen tel qu'il était calculé au moment de chaque vente". A builder following the mockup reads the version current at each sale; one following AD-42 reads today's.
- **Freshness.** `EditionSales` filters on the window live; the row is refreshed at settlement and at 00:30. Between a sale leaving the window and the nightly refresh, the chart disappears ("the edition has a sale in the window") while the price and its sale count still show, or the reverse.

**Fix (AD-51, third bullet):** "`Game::Market::EditionSales` returns a card-season's settled sales within the window the edition's price row was computed over, and, at each sale, `EditionPrice` applied with the current version's count and window to the sales up to and including it, the window ending at that sale. Its `average` series ends with one more point, at the row's computation time, equal to the row's average. The card page decides whether the chart shows from the same row (a row with sales used), never from a second count."

### H5. The browser formats numbers with raw `Intl`, against AD-18 and AD-40

**Units:** the server-rendered hero figures, tiles and `<details>` table (AD-18's server helper, AD-40's `picoins` helper, fr delimiter U+00A0) and the canvas axis ticks and tooltips (AD-51: "the browser formats it (`Intl`, in the page locale)").

`Intl.NumberFormat("fr-FR")` groups with U+202F (narrow no-break space), not U+00A0, and its compact form ("412,6 M", "413 M" depending on options) is not guaranteed to match the server's `picoins` compact form. The same figure on one page, in the hero and in the tooltip, is formatted two ways. AD-18 says "Numbers are formatted by one helper on each side that groups digits with U+00A0", and `app/frontend/lib/i18n.ts` already has `formatNumber`. AD-51 overrides it in one clause.

**Fix (AD-51, first bullet):** "Every number on a chart comes from the server. The browser formats it with AD-18's client helper and a client `picoins` compact form that a shared fixture tests against the server's, never with a raw `Intl` call, and never derives one."

---

## Medium

### M1. The three new writes publish no named event
`PublishChart`, `UnpublishChart` and `WriteDailySnapshot` change state. `AGENTS.md` and AD-10 require one primary event; AD-10 also exempts "housekeeping writes", and a builder can file the publication switch there. Name them, as AD-45 does for `CardsEntrusted`.
**Fix (AD-51, publication bullet):** "... write it, each publishing one event (`Game::Market::ChartPublished`, `Game::Market::ChartUnpublished`) heard by nobody at launch. Publishing a published chart or unpublishing an unpublished one changes nothing and publishes nothing." **(AD-48):** "`WriteDailySnapshot` publishes `Game::Market::DailySnapshotWritten`; a second run for the same day changes nothing."

### M2. "Not found to anyone but staff" conflicts with Pundit's refusal, and "staff" has two readings
A Pundit refusal on the economy page sends a visitor to `sign_in_required` (AD-14), not a 404. And "staff" is `moderator? || administrator?` in `Accounts::Player`, while the switch is "for administrators" and the back-office dashboard policy is `moderator?`: one builder shows unpublished charts to moderators, another only to administrators.
**Fix (AD-51, last two bullets):** "Its policy allows everyone; the controller answers not found when `Game::Market::ChartPublications.visible_kinds(viewer)` is empty. Staff means `Accounts::Player#staff?` (moderators included); the switch is administrator only and shows read-only to moderators."

### M3. "Sees" lets a builder render the chart and hide it with CSS
AD-18 invites rendering every variant and switching by CSS. A chart rendered and hidden still ships its JSON and its table to a visitor.
**Fix (AD-51):** "An unpublished chart is not rendered for a player or a visitor: no figure, no JSON, no table."

### M4. Words drawn inside the canvas have no locale path
Dataset names, tooltip lines, units ("j", "%"), the threshold label ("ALERTE 40 %", "CIBLE 1 À 2 J") are drawn by Chart.js. The JSON carries keys, not words. A builder writes them in the TS module (French only, against AD-18 and the both-locales rule). Separately, AD-30 says "an `Object` value carries only string templates", and AD-51 puts series in a Stimulus value: on any rich screen hosting a chart, the two rules collide.
**Fix (AD-51, component bullet):** "... the series as JSON in one Stimulus value, and the chart's words (series names, units, threshold label, tooltip lines) as templates under `charts.<kind>` in a second value, composed by `t()`. The series value is the one exception to AD-30's string-templates-only rule."

### M5. No series length is fixed
"A series ends on the last complete UTC day" fixes the end, not the start. A literal build returns all history: after two years, 730 points per series in an HTML attribute and a 730-row table on a public page.
**Fix (AD-51):** "The Reactor covers 30 days, the rarity prices and back-office indicators 90, the edition chart the price window; the length is a constant of `EconomySeries`, and the table lists the same rows."

### M6. Chart.js animates by default, against the reduced-motion switch
AD-27 has every Stimulus controller read one shared motion switch. AD-51 is silent; Chart.js animates every draw for 1 s.
**Fix (AD-51, controller bullet):** "... with Chart.js animation off (or on only when the shared motion switch allows it)."

### M7. Sparklines escape `ChartComponent`
The mockup's five price tiles each carry a mini line chart. AD-16 lets script build "canvases" and decorative `aria-hidden` nodes, so a builder draws them in a tile controller with Chart.js directly: a second chart path, with no table.
**Fix (AD-51):** "A sparkline is a `ChartComponent` of kind `sparkline`: `aria-hidden`, no title, no table, beside a server-rendered figure that carries its value."

### M8. Few sales: AD-51 draws a line the mockup removes, and the sale count has no source
`EditionPrice` drops nothing under three sales and returns an average, so a literal `EditionSales` draws the average line with two sales; the mockup's state "Public, peu de ventes" shows the points without a line and the "peu de ventes" mention. The mockup's "7 ventes en 90 jours" is a count of all sales in the window, while the price row stores only "the number of sales used" (at most the sale count setting).
**Fix (AD-51):** "Under the minimum sale count the edition chart shows the sales and no `average` series. The sale count shown beside the price is `EditionSales`' count."

### M9. The `threshold` series has no source
The 40 % alert is a value of `market-economy.md`, so a settings value (AD-42). The "cible 1 à 2 j" and "cible ≈ 40 j" targets are not in AD-42's list at all. A builder draws the current version's threshold flat across 90 days; another draws each day's version. Targets may end up hard-coded in the TS module.
**Fix (AD-48, alert bullet):** "Alert thresholds and day-of-income targets are settings (AD-42). `EconomySeries` returns the current version's value as a flat `threshold` series; a change of threshold does not redraw history."

### M10. "Never derives one" forbids what the mockup does, and allows what it should not
The mockup's tooltip prints "Solde du jour" (minted minus destroyed) computed in the browser, and draws destroyed bars below the axis by negating them. One builder drops the balance (losing the mockup's line), another derives it (breaking the rule).
**Fix (AD-51, first bullet):** "Display transforms (the sign of a bar drawn below the axis, axis ticks) are the pure module's; any total, difference or ratio a viewer reads, the day's balance included, is a server series."

---

## Low

1. **One word per figure.** The snapshot says "created", the JSON key `minted`, the token `--chart-minted`, the mockup "frappés". Pick `minted` everywhere in code. The keys of the four back-office series are not listed; list them (`destroyed_ratio`, `per_active_player`, `days_of_income`, `top_share`).
2. **DOM ids.** The `<figure>` and its table need ids for `aria-describedby`; say they derive from the chart kind and a per-page index, so an edition chart is never `chart-#{card_season.id}`.
3. **No style attribute.** The mockup's legend swatches and tile accents use `style="--c:…"`. Say legends and tiles take a class per series key, and that Chart.js's own runtime canvas sizing is the only inline style; the canvas's container is sized by CSS.
4. **Token names.** `--chart-*` departs from the `--color-*` convention, and "the rarity tokens and their shapes" puts point shapes (circle, triangle, star) in CSS custom properties. Say shapes are a constant of `app/frontend/lib/charts/`, keyed by rarity code name, and colors are `--color-chart-*` defined in `DESIGN.md`.
5. **Unpublish erases the audit.** One row per published chart, deleted on unpublish, loses who closed it and when. Either keep it insert-only like AD-42, or say the event (M1) is the record.
6. **Before the opening.** Snapshots run from the first deploy (AD-50), so the Reactor's first days are zeros from the closed period. Say series start at the market's first opening (`OpenMarket`'s version).
7. **Morph and refresh.** If a page with a chart is refreshed by morph, the controller must redraw on a change of its series value, not only on connect.
8. **Index for `EditionSales`.** It reads sold listings by card-season and `sold_at` on a public page; name the partial index (`card_season_id, sold_at` where `status = 'sold'`), added concurrently in its own migration. Also say whether the economy page shows while the market is suspended (AD-50) and from the teaser.

---

## Project rules checked against AD-51

| Rule (`AGENTS.md`) | Status |
| --- | --- |
| Write only through an operation; one event per operation | Operations named; events missing (M1) |
| A GET never writes | Holds: reads on the reading role; writes behind POST and a job |
| No database id in URLs, HTML, JSON, DOM ids, stream names | JSON holds; DOM ids unstated (L2) |
| A Pundit policy per action | Economy page and switch need policies; the 404 path conflicts with refusal (M2) |
| No `style` attribute in server HTML | Holds if legends and tiles use classes (L3) |
| Every string in both locales | Canvas words have no locale path (M4) |
| Script builds no markup | Holds, except sparklines (M7) |
| Planning ids out of code | AD-51 itself carries none into code paths |
