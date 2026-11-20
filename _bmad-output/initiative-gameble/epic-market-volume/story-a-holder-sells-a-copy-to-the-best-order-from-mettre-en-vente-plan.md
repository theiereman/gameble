---
title: 'A holder sells a copy to the best order from Mettre en vente'
type: 'feature'
ticket: '7'
created: '2026-11-20'
status: 'built'
baseline_revision: 'fac0d398540a60ca63e072e65229750acf062210'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred:
  - summary: >-
      TradedVolume, the market pulse's traded volume, still sums sold auctions only, so direct sales to orders trade PiCoins it does not show.
    evidence: |-
      Unverified intent. traded_volume.rb reads Listing.sold and its comment names "sold auctions"; the ticket names only the edition price, rarity_average and the edition chart as readers of served orders. Settle it by asking the author whether the pulse's volume counts direct sales; if so, read EditionPrice.sales there.
    location: >-
      app/domains/game/app/queries/game/market/traded_volume.rb:27
    severity: medium (unverified)
  - summary: >-
      config/routes.rb is over script/check_file_sizes' 400-line limit, so bin/ci and the CI size check fail.
    evidence: |-
      Pre-existing: the file was 401 lines at the baseline commit; this story's one route makes it 402. Splitting the market routes into their own drawn file is a change to a file every parallel lane edits, so it is left to the author or the sweep.
    location: >-
      config/routes.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Buy orders hold PiCoins (entry 2) but nobody can serve one: there is no eligibility reader, no direct-sale operation, and a served order would count nowhere in the edition's average price.

**Approach:** `EligibleOrders`/`BestEligibleOrder` as the one eligibility reader; `SellToOrder` serving the best eligible order the seller saw through epic 39's settlement step, generalised to serve a listing or an order; one merged sales source (sold listings + served orders) read by `EditionPrice`, `rarity_average` and `EditionSales`; on Mettre en vente the best-order banner with VENDRE MAINTENANT, its inline refusal and the VENDUE panel.

## Boundaries & Constraints

**Always:** writes only through `SellToOrder`; GET never writes; tokens only (order token, card ref) in HTML/URLs; Pundit on the new action; rate limited per player; every string in `en.yml` and `fr.yml` (French as the Copy deck draws it, English beside it), `errors.game.best_order_changed` by hand in both; French U+202F before `:` `;` `?`; no planning ids; files ≤400 lines Ruby/TS, ≤500 CSS; markup server-rendered, script clones server `<template>`s; no `style` attributes. Lock order: both bank locks ascending player id (held when `OrderServed` publishes), then both holdings ascending player id, then the order row.

**Never:** the wanted table or `RefreshWanted` (entry 6, built in parallel); event subscriptions for `OrderServed` beyond what exists (feed is entry 10, bell is entry 12); `ApplyWantedChoices` (entry 8); DEMANDÉE counts (entry 13); MES ORDRES SERVI lines (entry 9); market chip-row CSS; alt signals; dropping flagged-account sales from the average (left open: every direct sale counts).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sell | open market, current token, seller holds a free copy, token = best eligible order | order `served` (seller, card-season, `served_at`, `average_after_sale`); copy moved seller→buyer, seller `reserved` unchanged; one post: buyer `purchase` (committed −price, order's version), seller `sale` (+price, order's version), seller `commission` (−commission at the confirmed version), each `order_id`, no stamp; `OrderServed` once | none |
| Priority | several eligible orders | best price, then oldest `created_at`, then lowest id | — |
| Skipped | seller's own order; owner banned/deleted; price below the edition rarity's minimum at the order's version; other game; expired/not open | not eligible | — |
| Changed | posted token ≠ best eligible (served, withdrawn, better one placed), before or after the locks | nothing moves | `:best_order_changed` |
| Stale / closed | token ≠ current / market not open | nothing | `:amounts_changed` / `:market_closed` |
| Not free | quantity − reserved < 1 (deck, trade offer, listing reserve) | nothing | `:copy_not_free` |
| Deadlock | `ActiveRecord::Deadlocked` | nothing | `:market_busy` |
| Removed seller | banned/deleted | nothing | `:player_required` |
| No rarity | card-season without rarity | nothing | `:best_order_changed` (no eligible order) |

</intent-contract>

## Code Map

- `app/domains/game/app/operations/game/market/auction_settlement.rb` -- `settle_sale` (allocation, `move` seller/buyer, showcase cleanup, tiers `reached_by: "trade"`, listing sold, `refresh_edition_price`, `sale_entries` with the listing's version). Split into reusable private steps: `lock_sale_holdings` (exists), a seller part (move given, `released:` what the caller releases, showcase), a buyer part (allocation, move gained, tiers; the Archive purchase will reuse it), `refresh_edition_price(card_season_id, now, adding: nil)` returning the average (with `adding:` the price of a sale not yet saved is put first, then the window cut to `average_sale_count`: the orders table's served check demands `average_after_sale` in the same update as `status: served`), and `sale_entries` taking the buyer, seller, price, held, the reference (`listing_id:` or `order_id:`), the pricing version and the commission's version. `CloseAuction` behaviour unchanged (its tests must pass untouched).
- `app/domains/game/app/operations/game/market/close_auction.rb`, `move_holdings.rb`, `trade_locks.rb` (`TradeLocks.players(*ids)` sorts; `holdings(player_id, ids)` locks), `operation.rb` (`require_player`, deleted check in `lock_bank`; advisory locks are re-entrant), `list_card.rb` (`current_settings` shape, `free_copy`).
- `app/domains/game/app/models/game/market/order.rb` -- `open_at(now)`, `reaching(rarity)` (the only reach formula). `served` needs seller_id, served_card_season_id, served_at, average_after_sale together.
- `app/domains/game/app/models/game/market/edition_price.rb` -- `sales_in_window`, `rarity_average` read `Listing.sold`; `edition_sales.rb` the same. Replace with one merged source: `UNION ALL` of sold listings (`card_season_id, sold_at, final_price, average_after_sale, 0 source, id`) and served orders (`served_card_season_id, served_at, price, average_after_sale, 1, id`); newest first is `sold_at DESC, source DESC, id DESC`. `refresh_edition_prices.rb` reads `sales_in_window` and follows.
- `app/domains/game/app/queries/game/market/wanting_players.rb` -- query module style; `Accounts::Player.removed` scope.
- `app/controllers/market/sales_controller.rb` -- `load_page`, `choose`, `keep_posted_values`, `refuse_sale`, `sale_prices` (refs → ids via `EntrustableCopies.resolve`); `throttle_player` (Rails `rate_limit`; give the new action the same limit via `only: %i[create sell]`). `app/policies/market/sale_policy.rb`.
- Views `app/views/market/sales/{new,_cell,_fields,_summary,_refusal}.html.erb`; `app/helpers/market_sales_helper.rb` (`sale_edition_data`, `SALE_REFUSAL_SLOTS`, `sale_root_data`); `ButtonComponent` (add `formaction:` to `field_options` for submit buttons); `PanelComponent`; `app/views/market/listings/_outcome.html.erb` (the VENDUE panel markup to mirror).
- Frontend `app/frontend/controllers/listing_{form,fields,summary}_controller.ts`, `app/frontend/lib/listing_form{,_view}.ts` (+ tests): `Edition` from cell `data-*`; `showPrice` clones a per-ref `<template>` into a slot (mirror it for the banner); `summaryViewOf` status; `submit` validates the start price (must not for the direct-sale submitter).
- Tests to mirror: `test/domains/game/market/{close_auction,place_order,edition_price,edition_sales,edition_price_settlement}_test.rb`, `test/support/{market,market_bidding,market_sales,holdings}.rb`, `test/controllers/market/sales_controller_test.rb`, `test/system/market_sales_test.rb`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/eligible_orders.rb` -- `EligibleOrders.call(card_season_id, except:, now:)` → ordered relation (open at now, card = edition's card, `reaching(edition rarity)`, `player_id <> except`, owner not in `Accounts::Player.removed`, `price DESC, created_at, id`); `EligibleOrders.best(card_season_ids, except:, now:)` → `{ card_season_id => Order }` for a grid (grouped by rarity, `DISTINCT ON (card_id)`), built on the same private scope. `best_eligible_order.rb`: `BestEligibleOrder.call(card_season_id, except:, now:)` = first row.
- [ ] `auction_settlement.rb` -- split per Code Map; listing path unchanged.
- [ ] `app/domains/game/app/operations/game/market/order_serving.rb` -- module including `AuctionSettlement`: `serve_order(order:, seller_id:, card_season_id:, holdings:, commission_settings:, now:)` moves the copy releasing nothing, refreshes the edition price with `adding: order.price`, marks the order served with its average, returns the ledger entries (shared with entry 8).
- [ ] `app/domains/game/app/operations/game/market/sell_to_order.rb` -- `call(player:, card_season_id:, order_token:, settings_token:)`: require_player; `now`; seen = `BestEligibleOrder` unlocked, token must match else `:best_order_changed`; transaction: `TradeLocks.players(seller, buyer)`, seller not deleted, `current_settings`, `lock_sale_holdings`, `Order.lock.find`, recheck best at `now` is still seen (id) else `:best_order_changed`, free copy else `:copy_not_free`, `serve_order`, one `Ledger.post`, `publish(OrderServed.about(order), stream_name: seller)`; rescue Deadlocked → `:market_busy`.
- [ ] `edition_price.rb`, `edition_sales.rb` -- merged sales source per Code Map.
- [ ] `config/routes.rb` (additive) -- `post "market/sell/order" => "market/sales#sell", as: :market_order_sale`.
- [ ] `sale_policy.rb` -- `sell? = player?`.
- [ ] `sales_controller.rb` -- `load_page` loads best orders for the page's copies and the chosen copy (only when the market is open); `sell`: ref → card-season, `SellToOrder` with `params[:order]`, `params[:settings]`; success → `flash[:sold_to_order] = { card:, received: }` and redirect (see_other) to the Mettre en vente page (card variant when `params[:card]`); failure → `refuse_sale`-like render with slot `:order`, the banner redrawn with the new best order or the no-order line; refusal text: `best_order_changed` with a new best order still eligible → "Un meilleur ordre vient d'arriver : <amount>. Vérifiez-le, puis validez de nouveau.", otherwise `errors.game.best_order_changed` ("Cet ordre d'achat vient d'être servi. Vérifiez le nouveau meilleur ordre, puis validez de nouveau."); other codes as today's slots. Keep the file ≤400 lines (extract a concern if needed).
- [ ] `app/views/market/sales/_order_banner.html.erb` + `_fields.html.erb`, `_cell.html.erb`, `_summary.html.erb`, `new.html.erb` -- banner slot at the top of the fields (above the price, so also the phone's step 2), drawn server-side for the chosen copy (with the refusal sentence `role="alert" tabindex="-1"` when refused), a per-cell `<template>` for the others; banner: "Un ordre d'achat vous attend : <amount>", "Vente immédiate, sans timbre. Vous recevez <received> (Effort de la Confrérie : <commission>)." at the current version, `ButtonComponent` primary submit `name: "order"`, `value: token`, `formaction: market_order_sale_path`, accessible name "Vendre maintenant à l'ordre d'achat, <received> PiCoins reçus"; no-order line "Aucun ordre d'achat pour cette carte."; METTRE EN VENTE rendered secondary while a banner shows; the VENDUE panel ("VENDUE", "<card> est vendue à un ordre d'achat. Vous recevez <amount>.", heading focused) at the head of the page after success. `sale_edition_data` gains the order price (empty when none).
- [ ] `app/frontend/lib/listing_form.ts`, `listing_form_view.ts`, `controllers/listing_{form,fields,summary}_controller.ts` -- `Edition.order: number | null`; the banner template follows the choice like the price; the summary toggles the submit between primary and secondary; the summary status prefixes "Un ordre d'achat vous attend : <amount>" (`strings.orderWaiting`); `submit` skips the start-price validation for the direct-sale submitter and submits once (second activation prevented); on connect, focus a refused banner's sentence.
- [ ] `app/frontend/styles/market-sale-order.css` (+ `application.css` import) -- banner panel with a gold left accent, phone layout.
- [ ] `config/locales/en.yml`, `fr.yml` -- banner, no-order line, button name, VENDUE panel, better-order refusal, `market.sales.strings.order_waiting`, `errors.game.best_order_changed`.
- [ ] Tests -- `test/domains/game/market/{eligible_orders,sell_to_order}_test.rb` (every matrix row; ledger reconciles via `ReconcileWallets`; one free copy sold beside a deck block, a trade offer and an open listing on the same edition, `reserved` unchanged; commission at the confirmed version while the order's version differs; `average_after_sale` stored; a stale version refused; `CloseAuction` tests still green); `edition_price_test.rb`/`edition_sales_test.rb` (served orders merged with sold listings in time order, in `rarity_average` too); `sales_controller_test.rb` (visitor refused, throttle, banner/no-order line, refusal redraw, no ids in HTML); vitest for the new state/view; `test/system/market_direct_sale_test.rb` (Verify flow).

**Acceptance Criteria:**
- Given a holder of a copy another player's order reaches, when they choose it in Mettre en vente, then the banner shows the order's price less the commission and VENDRE MAINTENANT is the one primary button; when they press it, then the VENDUE panel shows, the buyer holds the copy and the order is served.
- Given a better order placed after the screen was drawn, when the holder presses VENDRE MAINTENANT, then the banner redraws with "Un meilleur ordre vient d'arriver : <new amount>…", focus is on that sentence, and nothing moved.
- Given served orders and sold listings on an edition, when the edition price, `rarity_average` and the edition chart are read, then both kinds count, in time order.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session verified and reviewed.
- The sale posts the listing form to `post market/sell/order` (`sales#sell`) through the SELL NOW button's `formaction` (new `ButtonComponent` option), its `name="order"` value the order token, beside the form's `settings` token; listing and direct sale share the 10-a-minute throttle bucket.
- Refusal text: "Un meilleur ordre vient d'arriver" only when the posted order is still eligible but outbid; a served, withdrawn or expired order gets `errors.game.best_order_changed` (the Copy deck's served sentence). Only `best_order_changed` redraws in the banner; other codes keep their existing slots, and it falls back to the form slot when no banner is drawn (closed market).
- The buyer's season allocation now runs after the seller's copy moves instead of before; `CloseAuction` tests pass unchanged.
- `EditionPrice.sales` aliases the union as the listings table so `where(card_season_id:)` and `pluck` keep a listing's column names; readers only pluck.
- The vitest controller test mounts the form root on a `div` (happy-dom does not match Stimulus targets inside a `form` root).
- `config/routes.rb` was already 401 lines at the baseline (limit 400); the new route makes it 402 (deferred).

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 36 findings — high 0, medium 2, low 26, false 5, maybe-false 3
- findings:
  - `[low]` `[reject]` blind: the served refusal copy is shown for cancelled, withdrawn and expired orders too — the Copy deck defines only the served and the better-order sentences (copy to approve); the author approves the copy in review.
  - `[low]` `[reject]` blind: the controller re-derives outbid after the operation — the message can only disagree in a race between two requests; a second failure code adds surface for a sentence choice.
  - `[low]` `[reject]` blind: `current_settings`/`free_copy` copied from ListCard — PlaceOrder repeats the same step; a shared module is the refactor sweep's.
  - `[low]` `[reject]` blind: OrderServing includes AuctionSettlement and inherits auction helpers — private methods, no caller diverges; renaming the module is the sweep's.
  - `[false]` `[reject]` blind: `now` read before the locks lets an order expiring meanwhile be served — the ticket asks for the recheck "at the now it read".
  - `[low]` `[reject]` blind: `EditionPrice.sales` is typed Listing over order rows — every reader plucks; no write reaches it.
  - `[low]` `[reject]` blind: the VENDUE amount is recomputed from the posted settings token — the sale succeeded only with that token current, so it is the version the commission was posted at.
  - `[low]` `[reject]` blind: refs resolved twice per page — one indexed query; no named harm.
  - `[low]` `[patch]` blind: `.sale-order-slot:empty` never matched the server-rendered slot — slot rendered on one line; the banner test asserts it is empty before a choice.
  - `[medium]` `[patch]` blind: the `selling` guard never resets, so SELL NOW is dead after a back/forward-cache restore — reset on `pageshow`, with a vitest case.
  - `[low]` `[patch]` blind: missing tests (buyer removed between draw and press, no holding row, unresolved ref, phone layout) — added the removed-buyer test; a missing holding answers `copy_not_free` through the same nil check as a reserved one; the phone layout is a residual risk.
  - `[low]` `[reject]` blind: the wide `flex-wrap` rule sits in the feature stylesheet — it exists only for the banner slot; `market-sale.css` is at 410 of 500 lines.
  - `[low]` `[reject]` blind: the throttle shares the listing bucket and drops the card page — the listing throttle already lands there; one bucket per screen is the chosen limit.
  - `[medium]` `[patch]` edge: `selling` stays true after a bfcache restore or an aborted navigation — same root as the blind selling-guard row; patched with it.
  - `[low]` `[reject]` edge: PUT UP FOR SALE while a sale is in flight — both are server-guarded on free copies; a second action is the player's.
  - `[low]` `[reject]` edge: a filter reload keeps a stale banner for the same chosen ref — the posted token is refused with `best_order_changed` and the banner redrawn; the price slot behaves the same.
  - `[low]` `[patch]` edge: the empty slot adds a row — same fix as the blind `:empty` row.
  - `[false]` `[reject]` edge: an order expiring while waiting on the locks is served — same as the blind `now` row; the ticket fixes the now.
  - `[low]` `[reject]` edge: outbid shows the same order when it is best again on redraw — only in a race of three requests; the guard adds a branch.
  - `[low]` `[reject]` edge: "served" copy for a cancelled order — same as the blind copy row.
  - `[low]` `[reject]` edge: `formaction` with `href`/`method` silently dropped — no caller; only a submit button takes it already.
  - `[low]` `[patch]` verification-gap: no test of `adding:` with a full window — test with `average_sale_count: 3` and three earlier sales; the oldest drops and 900 counts.
  - `[low]` `[patch]` verification-gap: the form-slot fallback of the order refusal is untested — controller test with the market closed and the order changed.
  - `[low]` `[patch]` verification-gap: the chosen-edition span's `data-order` is untested — assertion added to the banner test.
  - `[maybe-false]` `[defer]` verification-gap: TradedVolume ignores direct sales — whether the pulse's volume should count them is the author's; deferred, medium unverified.
  - `[low]` `[reject]` verification-gap: a closed market with a changed order answers `best_order_changed` — the page also draws the closed notice; the sentence now shows in the form slot.
  - `[low]` `[reject]` intent: the phone step-2 banner is not exercised by a test — the slot lives in the fields the phone's step 2 shows; residual risk.
  - `[false]` `[reject]` intent: SELL NOW's visible label lacks the amount — EXPERIENCE.md names the button by its accessible name "Vendre maintenant à l'ordre d'achat, <amount> PiCoins reçus".
  - `[false]` `[reject]` intent: only the order refusal redraws the banner — EXPERIENCE.md's banner refusal is the changed best order; other refusals keep Market refusals' slots.
  - `[low]` `[reject]` intent: the served wording covers every changed case — same as the blind copy row.
  - `[low]` `[patch]` intent: the system test never reads the visible terms line — `/You receive\s+810/` asserted after choosing the copy.
  - `[low]` `[patch]` intent: the deck block and trade offer were faked with `reserved` — the test now reserves through `CreateDeck`/`AddCardToDeck`, `ProposeTrade` and `ListCard`; deck names on the screen are unchanged code.
  - `[maybe-false]` `[reject]` intent: `EligibleOrders.best` and `BestEligibleOrder` could disagree — both read the one private scope and priority; the controller better-order test reads the grid path, the operation tests the other; if true it would be low.
  - `[false]` `[reject]` intent: the refresh prepends instead of re-reading — the served check requires the average in the same update; the full-window test pins the result.
  - `[low]` `[reject]` intent: the rate limit is shared with listings — per player as asked; one bucket per screen.
  - `[maybe-false]` `[reject]` intent: the split settlement steps are not tested alone — CloseAuction and SellToOrder exercise both halves; if wrong it would be low.

## Design Notes

- `adding:` exists because `game_market_orders_served_check` requires `average_after_sale` with `status = 'served'`; the order's own sale is the newest in the window. Entry 8 collects its refreshes after every move; it must serve with the same step.
- Commission version: the seller confirms the commission drawn from the current version (the token they submit); purchase and sale stay at the order's version (AD-59).
- Stream: `OrderServed` goes to the seller's stream, as `AuctionSold` does; both bank locks are held when it publishes, which entry 6's `RefreshWanted` will require.

## Verification

**Commands:** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w46_7 PARALLEL_WORKERS=4`)
- `bin/rails test test/domains/game/market test/controllers/market` -- green
- `bin/rails test` -- green
- `bin/rails test test/system/market_direct_sale_test.rb test/system/market_sales_test.rb test/system/edition_sales_chart_test.rb` -- green
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- pass
- Do not commit or stage: the orchestrating session commits. Leave `package-lock.json` (another session's change) untouched. Do not edit the market chip-row styles in `app/frontend/styles` (another lane). Always export the private `DATABASE_URL` above and `PARALLEL_WORKERS=4` (create the database with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing). Never run the whole system suite. No migration is expected.

## Auto Run Result

- **Summary:** a holder sells one free copy to the best eligible buy order from Mettre en vente. `EligibleOrders` (one edition, or the best per edition for the grid) and `BestEligibleOrder` are the one eligibility reader. `SellToOrder` reads the best order unlocked, takes both bank locks ascending, checks market and version, locks both holdings ascending then the order, rechecks the best order, needs a free copy, serves through `OrderServing` and posts once (purchase and sale at the order's version, commission at the confirmed one, `order_id`, no stamp), then publishes `OrderServed` on the seller's stream with both bank locks held. Epic 39's settlement is split into seller and buyer parts, `refresh_edition_price(adding:)` and a general `sale_entries`. `EditionPrice.sales` merges sold listings and served orders for the edition price, `rarity_average` and the edition chart. The screen: best-order banner or no-order line per chosen copy, METTRE EN VENTE secondary while an order waits, the status line, inline refusal with focus, the VENDUE panel.
- **Files:** `eligible_orders.rb`, `best_eligible_order.rb`, `order_serving.rb`, `sell_to_order.rb` (new); `auction_settlement.rb` (split), `edition_price.rb`, `edition_sales.rb` (merged source); `sales_controller.rb` (`sell`, best orders, refusal text), `sale_policy.rb`, `routes.rb`; views `market/sales/{_order_banner,_sold_to_order}` (new), `_cell`, `_fields`, `_summary`, `new`; `market_sales_helper.rb`; `button_component.rb` (`formaction:`); frontend `listing_form{,_view}.ts`, `listing_{form,fields,summary}_controller.ts`, `market-sale-order.css`, `application.css`; `en.yml`, `fr.yml`; tests `eligible_orders_test`, `sell_to_order_test`, `market_direct_sale_test` (system), `listing_form_controller.test.ts` (new) and additions to edition price/sales, sales controller, button component, listing form vitests; `test/support/market_orders.rb`, `market_sales.rb`.
- **Review:** 36 findings (high 0, medium 2, low 26, false 5, maybe-false 3). Patched 8 entries: 1 medium (the sell-once guard reset on `pageshow`) and 7 low (empty order slot, removed-buyer test, full-window `adding:` test, closed-market fallback test, chosen-span `data-order` assertion, visible terms line in the system test, real deck and trade-offer reservations). Deferred 2 (TradedVolume and direct sales, medium unverified; routes.rb over its size limit, pre-existing). Every rejected finding carries its reason in the triage log.
- **Follow-up review:** false (no high, one medium patched).
- **Verification:** `bin/rails test` 6335 runs, 0 failures (private database `gameble_test_w46_7`, `PARALLEL_WORKERS=4`); system tests `market_direct_sale`, `market_sales`, `edition_sales_chart` 8 runs green; `npm run test:js` 1545 green; `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `i18n-tasks missing` pass; `script/check_file_sizes` fails only on `config/routes.rb` (401 lines at the baseline, 402 now). No migration.
- **Residual risks:** the phone step-2 banner was not seen in a browser; the English copy and the French drafts are the author's to approve; flagged-account direct sales count in the average (left open by the UX review); entry 6's `RefreshWanted` will rely on both bank locks being held when `OrderServed` publishes, which `SellToOrder` does.
