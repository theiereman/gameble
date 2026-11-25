---
title: 'Buy order screen shows the card, drops its noise, and reprices an open order in place'
type: 'feature'
ticket: ''
created: '2026-11-25'
status: 'built'
baseline_revision: 'e56f996d1a3796150f7e8b15440024a4ec3b6d2c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context:
  - '{project-root}/docs/design-system.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The buy order screen never shows the card being asked for, its right-hand box carries lines a player does not need (rarities reached, the next-rarity sentence, the available balance and the "never bids for you" line), and an order already open shows only a sentence and a MES ORDRES link that loops between the two screens with no way to change the order.

**Approach:** Draw the card on the left of the order screen, cut the right-hand box down to price, held amount, duration, best order and submit, and, when the player already has an open order on the card, show that same form prefilled with its price so the player can reprice it in place through a new operation.

## Boundaries & Constraints

**Always:** An order is one card at one price (no quantity column exists): "update" means changing the price. Repricing goes through a new `Game::Market::RepriceOrder` operation that takes the bank lock, then locks the order scoped to the player, refuses an order no longer open, refuses a price that reaches no rarity, holds only the increase (refusing it when not covered) or releases the decrease in one ledger entry, and publishes one `OrderRepriced` event the wanted-refresh handler also hears. Route by order token, never a database id; new action gets a Pundit rule; every new string in en.yml and fr.yml; `errors.game.<code>` keys added by hand.

**Never:** No quantity column or migration. Do not delete `market.orders.strings.*` (MES ORDRES result rows still use them). No MES ORDRES link on the order screen. No change to how an order converts into a bid, expires or is served.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Raise | open order at 20, available 50, new price 30 | order price 30, 10 more held, form shows 30 | No error expected |
| Lower | open order at 30, new price 15 above the lowest minimum | price 15, 15 released | No error expected |
| Same price | new price equals current | Success, no ledger entry | No error expected |
| Not covered | raise exceeds available | order unchanged | `Failure(:not_covered)` shown in the field |
| Too low | price below every rarity minimum | order unchanged | the existing too-low failure code |
| Gone | order expired, served or cancelled meanwhile | nothing changes | `Failure(:order_not_open)`, form re-renders as a new order |
| Market closed | settings closed | form disabled | existing closed refusal |

</frozen-after-approval>

## Code Map

- `app/views/market/orders/new.html.erb` -- two-column page; left column renders `_available`; right panel renders `_running` or `_form` (l.23-27).
- `app/views/market/orders/_form.html.erb` -- the form; `.order-form__reach` block l.27-42 (reached label, chips, sentence, conversion, live status) and the `available` line l.71 go.
- `app/views/market/orders/_running.html.erb` -- sentence + MES ORDRES link; replaced by the prefilled form.
- `app/views/market/listings/show.html.erb:21-24` -- card-on-the-left pattern (`.market-listing__card`, `CardComponent.new(card:, size: :l)`); `@detail.view` is the card view already on the order page.
- `app/controllers/market/orders_controller.rb` -- `new`/`create`, `load_terms` sets `@running` (l.47), `answer_placed` (l.62).
- `app/policies/market/order_policy.rb` -- add `update?` (`player?`).
- `config/routes.rb:58-62` -- order routes; cancellation already keyed by `:token`.
- `app/domains/game/app/operations/game/market/place_order.rb` -- reach/covered checks and `:hold` ledger entry to mirror; `cancel_order.rb` -- order lock + `:release` entry; `place_bid.rb:95-105` -- hold-only-the-difference pattern.
- `app/domains/game/app/queries/game/market/order_id_by_token.rb` -- token lookup.
- `app/domains/game/app/handlers/game/market/handlers/wanted_refresh.rb`, `handlers/game/handlers/metrics.rb` -- subscribe to `OrderPlaced`; add `OrderRepriced` to wanted refresh.
- `app/helpers/market_orders_helper.rb` -- `order_reach_sentence` (l.5), `order_running_line` (l.89); drop what becomes unused.
- `app/frontend/controllers/order_form_controller.ts`, `app/frontend/lib/order_form.ts` (+ `.test.ts`) -- `chip`/`sentence`/`status` targets and `sentence()` go.
- `app/frontend/styles/market-orders.css:10-95` -- reach/chip styles go; add the card column.
- Tests: `test/controllers/market/orders_controller_test.rb`, `test/domains/game/market/place_order_test.rb` (model for the new op test), `test/system/market_orders_test.rb`, `test/support/market_orders.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/operations/game/market/reprice_order.rb` + `app/domains/game/app/events/game/market/order_repriced.rb` -- new operation and event per Boundaries.
- [x] wanted refresh handler -- also subscribe to `OrderRepriced`.
- [x] `config/routes.rb`, `app/policies/market/order_policy.rb`, `orders_controller.rb` -- `PATCH market/orders/:token` → `Market::OrdersController#update`; on success redirect back to the order screen with the same `from`/goal chain and a flash line; on failure re-render `new` with the refusal; `load_terms` prefills `@price_text` from `@running`.
- [x] `new.html.erb`, `_form.html.erb`, delete `_running.html.erb` -- card on the left above `_available`; form posts to update when `@running`, with a submit label for the reprice and the existing cancel action beside it; remove the reach block and the available line.
- [x] helper, TS controller/lib, CSS, en.yml + fr.yml -- remove dead code and keys (`reached`, `chip_*`, `conversion`, `available`, `my_orders`), add the reprice keys and the error message.
- [x] tests -- operation test covering every matrix row; controller test for update + policy; update system test for repricing and for the card shown; vitest drops the sentence cases.

**Acceptance Criteria:**
- Given a player on a card's order screen, when it loads, then the card is drawn on the left and the right box shows no rarity chips, no next-rarity sentence and no available balance line.
- Given a player with an open order on that card, when they open it from MES ORDRES, then the same form appears prefilled with its price and offers to update or cancel, with no MES ORDRES link.

## Plan Change Log

- 2026-11-25, verification: `Ledger.post` hit `index_game_market_ledger_entries_one_order_entry` (one entry per order, player and kind), so an order cannot take a second hold or release. Author decision: a reprice replaces the order, no migration. In one transaction under the bank lock, `RepriceOrder` locks the old order, refuses it unless open, marks it cancelled with its full `:release` entry, creates a new order on the same card at the new price under the current settings with its own `:hold`, and publishes one `OrderRepriced` naming both orders. Coverage counts the release (available + old price >= new price). Same price: Success with no write. The new order gets a new token and a fresh expiry, and MES ORDRES keeps the cancelled one. The controller redirects to the order screen, which finds the new open order. KEEP: the screen, card column, removed lines and tests already built.

## Design Notes

The order screen is already reached from MES ORDRES rows (`my_orders/_group.html.erb:7` links to `new_market_card_order_path`), so no show route is needed: the "detail" is the new screen in edit mode.

## Verification

The implementation agent writes the tests but does not run any suite; the main session runs these once.

**Commands:**
- `bin/rails test test/domains/game/market test/controllers/market` -- expected: green
- `bin/rails test test/system/market_orders_test.rb` -- expected: green
- `npm run test:js && npm run format:check && npm run lint:css` -- expected: green
- `bundle exec packwerk check && script/check_file_sizes && script/check_planning_references` -- expected: clean

## Review Triage Log

Pass 1 (quick): high 0, medium 2, low 2, false 1.
- medium, patch — OrderNotices ignores OrderRepriced: `order_notices.rb` EVENTS lacks it, so the replaced order's listed_above_order notices stay. Fix: subscribe and end the replaced order's notices.
- medium, patch — reprice ignores the posted settings_token, unlike `PlaceOrder#current_settings`. Fix: refuse `:amounts_changed`.
- low, patch — update never checks the token's order against the slug's card; a mismatched PATCH redraws another card. Fix: 404.
- low, patch — reprice skips the published-card check `PlaceOrder` enforces. Fix: same refusal.
- false — "Lower" ledger shape differs from the matrix: the Plan Change Log decision (replace the order) defines full release + new hold; net amounts match.
