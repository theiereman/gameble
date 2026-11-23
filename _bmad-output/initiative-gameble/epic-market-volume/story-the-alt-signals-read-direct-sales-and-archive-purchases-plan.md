---
title: 'The alt signals read direct sales and Archive purchases'
type: 'feature'
ticket: '19'
created: '2026-11-23'
status: 'built'
baseline_revision: 'ba6499b9e169301aed8ca8cdc493c1bea3fd0fab'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The sale signals (sales outside price, minimum-price sales) and so the ties read only sold listings, so a direct sale to an order goes unseen, and nothing flags an alt's order served by its main account or an Archive round trip between tied accounts.

**Approach:** `EditionPrice::SALES`, the one union of sold listings and served orders, gains seller, buyer and settings columns; `SalesOutsidePrice` and `MinimumPriceSales` read it, so ties include direct sales. Two signals join `AltSignals::SIGNALS`, each reading the refresh's ties and making none, as `TiedBids` does: `order_sale_to_tied_buyer` (one row per served order of the window whose seller and buyer are tied; account the seller, other the buyer; facts card slug, season, price) and `archive_purchase_of_tied_deposit` (one row per Archive purchase of the window and tied depositor of that edition whose deposit row was updated in the window; account the buyer, other the depositor; facts card slug, season, price, copies deposited and the deposit's date). Their labels and sentences in both locales; the back-office page renders them through the existing rows table.

</intent-contract>

## Tasks & Acceptance

**Acceptance Criteria:**
- Given two accounts tied by three minimum-price direct sales, when the refresh runs, then `minimum_price_sales` ties them and each sale raises `order_sale_to_tied_buyer` naming the seller, the buyer and the order's price.
- Given served orders under half and over twice the edition's average between two accounts, when the signals are detected, then `sales_outside_price` names the pair.
- Given a tied pair, when the buyer bought from the Archives an edition the other account entrusted in the last 30 days, then `archive_purchase_of_tied_deposit` names the buyer, the depositor and the deposit; a deposit or a purchase older than 30 days, or an untied depositor, raises nothing.
- Given the new rows, when staff open the signals page, then each shows its label and its facts sentence.

## Implementation Notes

Oneshot: about a hundred lines of code across the sales union, two detectors edited, two added, the sentence component and the strings, all following `TiedBids`.

- The minimum-price reading of an order sale is the serving copy's rarity minimum in the order's settings version (the version it was placed under), as a listing reads its own rarity in the version it was created under. Both direct-sale entry points (`SellToOrder`, `ApplyWantedChoices`) serve orders through `OrderServing`, so reading served orders covers both.
- Left open by the ticket and not built: signals for spoofing, repeated relisting, and goals overlapping a tied account's listings.
- Facts carry the card slug and season number, never ids; `AltSignalSentenceComponent` formats only integer facts, so a slug made of digits stays as written.
- `EditionPrice::SALES` gained `seller_id`, `leader_id` (the order's owner for a served order) and `settings_id`; `MinimumPriceSales` reads `EditionPrice.sales` in place of `Listing.sold`, and `SalesOutsidePrice` reads the union, its window ordered by `sold_at, source, id` as `NEWEST_FIRST` is.
- The Archive signal takes "the same window" as both the purchase and the deposit row's `updated_at` within the last `MARKET_WINDOW_DAYS`; a buyer's own deposit never counts. The deposit's date is stored as an ISO date in the facts.
- The signals page's intro now names Archive purchases in both locales; the page itself is unchanged, the two signals render in the existing rows table.
- Surprise: none; the three new sale-signal tests fail with the two sale signals reverted.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/domains/game/market/alt_signals_market_test.rb test/domains/game/market/refresh_alt_signals_test.rb test/components/alt_signal_sentence_component_test.rb test/controllers/back_office/market_signals_controller_test.rb test/domains/game/market/edition_sales_test.rb` -- expected: green
- `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec rubocop` on touched Ruby -- expected: pass

## Auto Run Result

**Summary:** the sale signals read served orders beside sold listings (so direct sales also tie accounts), and two signals read the refresh's ties without making any: `order_sale_to_tied_buyer` (each direct sale of the last 30 days to a tied buyer's order: seller, buyer, card, season, price) and `archive_purchase_of_tied_deposit` (each Archive purchase of the last 30 days of an edition a tied account's deposit row was updated for in the same window: buyer, depositor, card, season, price, copies entrusted and their last date). Both show on the back-office signals page with their labels and sentences in both locales.

**Files changed:**
- `app/domains/game/app/models/game/market/edition_price.rb` -- the sales union carries seller, buyer and settings
- `app/domains/game/app/queries/game/market/alt_signals/minimum_price_sales.rb`, `sales_outside_price.rb` -- read served orders
- `app/domains/game/app/queries/game/market/alt_signals/order_sales_to_tied_buyer.rb`, `archive_purchases_of_tied_deposit.rb` -- the two new signals
- `app/domains/game/app/queries/game/market/alt_signals.rb` -- `SIGNALS` gains them; the refresh's ties feed them
- `app/components/alt_signal_sentence_component.rb` -- formats only integer facts
- `config/locales/en.yml`, `config/locales/fr.yml` -- labels, sentences, intro
- tests: `test/domains/game/market/alt_signals_direct_sales_test.rb` (new), `test/controllers/back_office/market_signals_controller_test.rb`

**Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).

**Verification:** alt-signal, refresh, sentence component, signals controller and edition price tests (101 runs) green, then the controller, new signal and `test/config` tests (81 runs) green, on `gameble_test_i` with 4 workers; `check_planning_references`, `check_file_sizes`, `packwerk check`, `i18n-tasks missing`, `zeitwerk:check` and rubocop on the touched Ruby pass. No migration, no TypeScript, no CSS.

**Residual risks:** the minimum-price reading of an order sale (the serving copy's rarity in the order's placement version) and the Archive window's reading are this build's choices on the ticket's open points; signals for spoofing, relisting and goal overlap are not built; the back-office system test was not rerun.
