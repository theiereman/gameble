---
title: 'A card''s detail shows its edition''s average price, kept current every night'
type: 'feature'
ticket: '41.1'
created: '2026-11-10'
status: 'in-progress'
baseline_revision: '231c45ca83e64d28ad829604df9e8773aa3139f9'
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

**Problem:** A sale stores its edition's average price, but nothing shows it and nothing brings it up to date when a sale leaves the window or the window setting changes. Epic requirements R1, R2, R5, R6, R8.

**Approach:** A housekeeping operation recomputes every price row with sales through `EditionPrice`, run by `ReconcileWalletsJob` after the reconciliation. A read-side query answers each card-season's price state, a component draws one state, and the card detail shows "Prix moyen S<n>" with its sale count for the displayed season's edition.

## Boundaries & Constraints

**Always:**
- `EditionPrice` stays the only formula; the refresh reads `CurrentSettings`, recomputes each row with `sales_used` above zero in its own transaction under the row's `FOR UPDATE` lock, writes only a row whose average or sales used changed, publishes no event and posts nothing.
- `EditionPrices` answers on the reading role for a list of card-season ids: priced (average, 3 sales or more), few sales (average, fewer than `MINIMUM_SALES`), no sale (no row or no sale used); before the market's first opening it answers nothing at all.
- `AveragePriceComponent` draws one state with `PicoinAmountComponent`: the amount; the amount followed by "peu de ventes" in the alert colour; "Sans vente" in muted. Stories 3 and 4 reuse it unchanged.
- The card detail's facts row reads "Prix moyen S<n>" for the displayed (published) season, with "Fondé sur <n> ventes" under it except for no sale; shown to players and visitors, on the public card page too, never on the card face; absent before the first opening.
- Copy in `en.yml` and `fr.yml`; the job runs the refresh even when the reconciliation reports a difference.

**Never:** an edition chart, a daily snapshot, a rarity average, a price anywhere else (stories 3 and 4), a new migration, a database id in the page.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- The price shown is the displayed edition's (the season in the card's address, or the published one by default), the one whose season number the row names.
- An edition under the minimum shows its average with "peu de ventes" and its sale count; the average of the formula is kept, only the mention changes.
- The refresh passes the time to the operation as an argument, as the archive stocks' does, and returns the number of rows it changed.
- The query answers an empty hash before the first opening, and a state for every asked id after it, so a view needs one lookup and no market-state read.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sale left the window | Row has 5 sales, one now older than the window | Refresh stores the new average and sales used | No error expected |
| Nothing moved | Row already matches the formula | Row untouched, `refreshed_at` kept | No error expected |
| Window setting changed | New version with a shorter window | Next refresh recomputes rows to it | No error expected |
| Every sale left | Row's sales all outside the window | Average nil, sales used 0, the row stays | No error expected |
| Three states | 5 sales / 2 sales / none | Priced, few sales, no sale | No error expected |
| Before the first opening | No settings or never opened | Query answers `{}`, no row on the card detail | No error expected |
| Job order | Reconciliation finds a difference | Difference reported, refresh still runs after | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/edition_price.rb` -- the formula and the row lock the refresh reuses.
- `app/domains/game/app/operations/game/market/sum_archive_stocks.rb` -- model of a housekeeping operation with no event.
- `app/domains/game/app/jobs/game/reconcile_wallets_job.rb` -- gains the refresh after the reconciliation.
- `app/domains/game/app/queries/game/market/current_settings.rb`, `models/game/market/market_state.rb` -- settings in force and the first-opening read.
- `app/components/picoin_amount_component.rb` -- drawn by the new component.
- `app/controllers/cards_controller.rb`, `app/views/cards/_detail.html.erb`, `_public.html.erb` -- the card detail and the public card page.
- `app/frontend/styles/card-detail.css`, `config/locales/en.yml`, `fr.yml` -- style and copy.

## Tasks & Acceptance

**Execution:**
- [ ] `Game::Market::RefreshEditionPrices` and the job's call -- recompute rows with sales
- [ ] `Game::Market::EditionPrices` -- price states for card-season ids
- [ ] `AveragePriceComponent`, helper, style, copy in both locales
- [ ] Card detail and public card page rows, controller load
- [ ] Tests: operation, query, component, job order, controller, one system test

**Acceptance Criteria:**
- Given the market has first opened, when a visitor opens the card detail of an edition with five sales, two sales and none, then it shows the amount, the amount with "peu de ventes", and "Sans vente", with "Fondé sur <n> ventes" under the first two, and nothing before the opening.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
