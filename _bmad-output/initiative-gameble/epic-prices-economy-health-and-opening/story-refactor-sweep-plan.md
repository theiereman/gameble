---
title: 'Refactor sweep'
type: 'refactor'
ticket: '41.10'
created: '2026-11-10'
status: 'draft'
baseline_revision: '9e6f1f46334907c3764cde22988aff6f8b24c15a'
route: ''
route_source: ''
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-follow-auctions-and-removed-players/story-refactor-sweep-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The classes and test support modules of epic 41 (edition prices, the nightly snapshot and its figures, the economy series and alerts, the alt signals, the back-office market pages, the collection price filters) carry explanatory doc comments the project forbids, and a few pieces of code and test setup are written twice.

**Approach:** Behaviour-preserving cleanups only: drop the explanatory comments from the classes and test files epic 41 created, name the alert's two setting fields once, and build every sold-listing test arrangement through one support helper. No behaviour, copy or schema change.

## Boundaries & Constraints

**Always:**
- Rendered text, rows, refusals and settings proposals stay identical; tests keep asserting the same things and only references follow a rename.
- Files stay under 400 lines (Ruby, TypeScript) and 500 (CSS); the largest epic 41 files are far under, so none is split.
- Every renamed or moved constant or method is changed in `app/` and `test/` together.

**Never:**
- No new feature, no change to a refusal, a locale string or a view; scope pushed out of another story is a new story.
- No comment added; the only comments kept are on classes epics 38 to 40 created and on external constraints.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- Comments are dropped only from what epic 41 created: `DailySnapshot`, `Median`, `WriteDailySnapshot`, `DailyFigures`, `EconomyAlerts`, `EconomySeries`, the alert part of `MarketSettingsForm`, the prepared form in `MarketsController`, the `MarketSnapshots` and `MarketSales` support modules and the headers of the price tests.
- The price-words formatting is already one helper (`AveragePriceHelper`) and the price filter already reuses `filters/_price`; neither is touched.
- `EconomyAlerts` names the stamp and minimum fields of a rarity once.
- `MarketSales#sold!` takes an optional buyer and average after the sale, so `AltSignalSeeds#sale!` and `MarketFeed#sale_entry!` stop building the sold listing themselves.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/**` (snapshot, figures, series, alerts, median) -- explanatory comments; `EconomyAlerts` field names
- `app/models/back_office/market_settings_form.rb`, `app/controllers/back_office/markets_controller.rb` -- comments on the prepared form
- `test/support/market_sales.rb`, `alt_signal_seeds.rb`, `market_feed.rb`, `market_snapshots.rb` -- duplicated sold listing, header comments
- `test/controllers/cards_average_price_test.rb`, `test/system/back_office_market_health_test.rb`, `test/controllers/library_prices_test.rb`, `test/system/library_prices_test.rb` -- header comments

## Tasks & Acceptance

**Execution:**
- [ ] epic 41 classes -- drop explanatory comments
- [ ] `economy_alerts.rb` -- one place for a rarity's stamp and minimum fields
- [ ] test support -- one sold listing helper; drop header comments
- [ ] price tests -- drop header comments

**Acceptance Criteria:**
- Given any page, proposal or snapshot produced before, when produced now, then the result is the same.
- Given the tests, when read, then each holds only its own setup and assertions.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c` on each touched file, `script/check_planning_references`, `script/check_file_sizes` -- expected: no errors
