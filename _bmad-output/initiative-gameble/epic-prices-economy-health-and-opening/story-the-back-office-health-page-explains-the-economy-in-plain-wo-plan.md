---
title: 'The back-office health page explains the economy in plain words'
type: 'feature'
ticket: '41.5'
created: '2026-11-10'
status: 'built'
baseline_revision: '24beb5709830e77166d8cc9167727d33f5bacbd5'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The snapshots exist but staff cannot read the economy from them. Epic requirements R12 to R14.

**Approach:** `EconomySeries`, the only reader of the snapshots, returns the four indicators over 90 days with their threshold or target series. A staff-only health page draws each indicator as a tile with its last value and three lines from locale keys, plus the last reconciliation, the day's snapshot and the oldest listing due to close.

## Boundaries & Constraints

**Always:**
- `EconomySeries` runs on the reading role and ends on the last complete UTC day; its lengths (90 days, 30 for the ratio) are constants; a day with no snapshot is null for every indicator, never 0; a threshold or target is the current version's value as a flat series, nil when the setting is blank.
- Destroyed against created is the ratio, in basis points, of the sums over the 30 days ending with each day, null without a snapshot that day or with nothing created; days of income is `price.fdiv(median)`, null when either is null, computed only there.
- The page is a GET with a Pundit policy open to staff; no write, no id, no `style` attribute.
- A tile with no last value, or no snapshot at all, says "Pas encore assez de données"; every other tile gives the value and, from locale keys, what is happening, why it matters and what to do.
- The market's back-office navigation, on this page and the market page, links the two pages; this story owns its entries.
- Copy in `en.yml` and `fr.yml`.

**Never:** a chart, the Reactor, a published-chart switch, an alert or its action (story 6), a dashboard tile with a new pixel icon, a write.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The query returns the series and the latest snapshot of the window as one value; the page reads the last reconciliation and the day's figures from that snapshot, so no other code reads the table.
- The health page lives at `back-office/market/health`, reached from a small navigation on both market pages, not from a new dashboard tile, which would need a pixel icon that cannot be hand-edited.
- Days of income shows its five rarities as rows of one tile, each with its value and target.
- Values read as: a percentage for the two shares, a compact PiCoin amount per player, days with one decimal.
- The oldest listing due is shown as a duration, or "No listing is due" when there is none.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| A week of snapshots | Seven days written | Each indicator with value and three lines, the day's figures, the reconciliation | No error expected |
| No snapshot | Table empty | Each tile says "Pas encore assez de données" | No error expected |
| Ratio | 30 days of created and destroyed | Sum of destroyed over sum of created, in basis points | Null with nothing created |
| Null median | Day with no earner | Days of income null, the point stays a gap | No error expected |
| Threshold change | New settings version | Threshold series follows the version in force, values unchanged | No error expected |
| A player | Signed in, not staff | The back-office refusal | Routing error as the other pages |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/oldest_due_listing.rb`, `current_settings.rb` -- read by the page.
- `app/controllers/back_office/markets_controller.rb`, `app/views/back_office/markets/show.html.erb` -- the market page that gains the navigation.
- `app/policies/back_office/market_policy.rb` -- model of the staff policy.
- `app/frontend/styles/back-office-market.css`, `config/routes.rb`, `config/locales/en.yml`, `fr.yml`.

## Tasks & Acceptance

**Execution:**
- [ ] `Game::Market::EconomySeries` -- the four indicators, the threshold series and the latest snapshot
- [ ] Policy, route, `BackOffice::MarketHealthController`, view, helper, navigation partial, style
- [ ] Copy in both locales
- [ ] Tests: query, controller, one system test

**Acceptance Criteria:**
- Given a week of snapshots, when staff open the health page, then they read the four indicators with their three lines, the last reconciliation, the snapshot's figures and the oldest due listing's age; with no snapshot each indicator says "Pas encore assez de données"; a player gets the back-office refusal.

## Implementation Notes

Built as planned; nothing was run. `EconomySeries` returns `Series` (days, the three single indicators, the five days-of-income indicators by rarity, the latest snapshot), each `Indicator` carrying its values and its flat threshold. The page is `BackOffice::MarketHealthController` at `back-office/market/health`; the indicator and income tiles share a `lines` partial for the three plain-word lines, which story 6 extends with the alert. The navigation partial is rendered on both market pages. The new keys are dynamic, so `config/i18n-tasks.yml` ignores them as unused.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
