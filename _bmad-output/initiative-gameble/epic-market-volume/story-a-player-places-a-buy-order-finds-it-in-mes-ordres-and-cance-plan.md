---
title: "A player places a buy order, finds it in MES ORDRES and cancels it"
type: 'feature'
ticket: '2'
created: '2026-11-20'
status: 'built'
baseline_revision: 'ae21a36542b1522663c28af4746692cb72a736d6'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred:
  - summary: >-
      PlayerOrders drops an open order whose card has no published face or no text in the viewer's locale, so its held PiCoins would show nowhere and could not be cancelled.
    evidence: |-
      Unverified. The rows come from LatestPublishedCardSeasons and CardViews (texts joined by locale) and filter_map skips a missing card. No catalog code unpublishes a season today. Settle it by confirming every published card has texts in both locales and that seasons never leave published; otherwise fall back to a minimal row.
    location: >-
      app/domains/game/app/queries/game/market/player_orders.rb
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Entry 1 laid the orders table, `Order.reaching` and the order events, but nothing places or cancels an order: no operation, screen, chip or button. This is the tracer through every layer: place an order holding PiCoins from a card's detail, see it in MES ORDRES, cancel it free.

**Approach:** `Game::Market::PlaceOrder` and `CancelOrder` (bank lock, one `Ledger.post`, one event); one query `OrderRarities` deriving reached rarities from `Order.reaching` only (settles entry 1's deferred item); PlayerStream's balance notice for every market-volume event; the Ordre d'achat screen (VOTRE ORDRE only), MES ORDRES (EN COURS only) as the fourth market chip, PASSER UN ORDRE on the card detail, `EmptyStateComponent`, a dev seed; copy in both locales.

## Boundaries & Constraints

**Always:** writes only through the two operations; GETs never write; tokens, never ids, in URLs/HTML/DOM; every action has a Pundit policy; every string in `en.yml` and `fr.yml` (French as the Copy deck draws it, English drafted beside it), every `errors.game.<code>` added by hand in both; additive edits only to `config/routes.rb`, locales and `event_store.rb`; no planning ids; files under 400 lines (Ruby/TS), 500 (CSS); markup server-rendered, script only toggles server-rendered nodes; no `style` attributes.

**Never:** DISPONIBLE MAINTENANT, the Archives' offer, Meilleur ordre en cours, the running-order line in place of the field, the goal head line (entry 11); TERMINÉS RÉCEMMENT, expiry, SERVI lines, "Cet ordre vient d'être servi." (entry 9); bell lines or `topic: "market"` notices for orders (entry 12); the market's empty-search PASSER UN ORDRE and goal suggestions (entries 13, 18); the back-office order duration field (entry 3, another lane); wanted-table code (entry 6, another lane); an unusual-price confirmation or a visitor's sign-in line (left open, see Design Notes); refactoring MES VENTES/MES ENCHÈRES empty states onto the new component (the sweep).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Place | open market, current token, published card, price ≥ some minimum, price ≤ available | order open, `expires_at = now + order_duration_days`, one `hold` entry (available −price, committed +price, `order_id`, `settings_id`), one `OrderPlaced` | none |
| Closed / suspended | `CurrentSettings.call&.open` false | nothing written | `:market_closed` |
| Stale version | token ≠ current | nothing written | `:amounts_changed` |
| Unpublished game | card with no rarity'd card-season in a published season | nothing written | `:card_not_published` |
| Already open | player has an `open` order on that card (even if due) | nothing written; concurrent insert caught by the index | `:order_already_open` (also on `RecordNotUnique`) |
| Below every minimum | price under every rarity's minimum | row rolled back | `:order_below_minimum` |
| More than available | price > `Balance.available` | row rolled back | `:more_than_available` |
| Bad price | "", "0", "abc" | nothing | `:invalid_price` |
| Deadlock | `ActiveRecord::Deadlocked` | nothing | `:market_busy` |
| Removed player | banned/deleted | nothing | `:player_required` |
| Cancel | own `open` order, market open or closed | `cancelled`, one `release` (available +price, committed −price, `order_id`), one `OrderCancelled` | none |
| Cancel twice / not open | status ≠ open | nothing | `:order_not_open` |
| Cancel another's / unknown | token not the player's | nothing | `:order_not_found` |
| Balance notice | each market-volume event | after commit, one balance notice per player concerned (OrderServed: buyer and seller; WantedChoicesApplied: seller and each sale's buyer) | none |

</intent-contract>

## Code Map

Backend (`app/domains/game/app/`):
- `operations/game/market/list_card.rb` -- the shape to copy: `require_player`, `amount` (`PriceAmount`, `:invalid_price`), `transaction`, `step lock_bank(player)`, `current_settings(settings_token)` (`:market_closed` / `:amounts_changed`; a suspended market has `open` false), `Ledger.post` then `step publish(..., stream_name: stream_name(player.id))`, `rescue ActiveRecord::Deadlocked` → `:market_busy`. A `Failure` inside `transaction` rolls back rows and event.
- `operations/game/market/cancel_listing.rb` -- cancel shape: `lock_bank`, then `X.lock.find_by(id:, owner)`.
- `operations/game/market/place_bid.rb` -- hold/release entry deltas; `Balance.call(player).available` for `:more_than_available`.
- `models/game/market/order.rb` -- `open_at(now)`, `reaching(rarity)` (the only formula), `RARITY_NAMES`; partial unique index `index_game_market_orders_one_open_per_card`.
- `models/game/market/ledger.rb` -- `Ledger::Entry.new(player_id:, kind:, available_delta:, committed_delta:, order_id:, settings_id:)`; post once, last.
- `events/game/market/order_*.rb`, `wanted_choices_applied.rb`, `archive_purchased.rb`, `events/game/slot_bought.rb` -- data keys (`player_id`; OrderServed `buyer_id`/`seller_id`; WantedChoicesApplied `seller_id` and `sales[].buyer_id`).
- `app/domains/catalog/app/queries/catalog/published_card_ids.rb` `within(ids)`; `card_detail.rb` `CardDetail.call(slug:, locale:)` (nil when unpublished; `.card_id`, `.view`); `latest_published_card_seasons.rb` + `card_views.rb` for a card-level view (title, image, slug as `id`) by card id.
- `queries/game/market/seller_listings.rb` -- row/query style for MES ORDRES; `market_state.rb` (`open?`, `suspended?`); `current_settings.rb`; `balance.rb`.
- `app/models/player_stream.rb` -- `BALANCE_EVENTS`; specific `when` branches precede `when *BALANCE_EVENTS` (generic `data[:player_id]`). `EVENTS` includes `BALANCE_EVENTS`, so `event_store.rb` needs no edit.

Web:
- `config/routes.rb` lines 37-55 -- flat strings in the locale scope (`get "market/sell/cards/:slug" => "market/sales#new", as: :new_market_card_sale`).
- `app/controllers/market/sales_controller.rb` -- `throttle_player to:, only:, path:, alert:`; refusal: `@refusal = Op.failure_message(code, **values)`, `render :new, status: :unprocessable_content`; `app/controllers/market/cancellations_controller.rb` -- POST cancel, `redirect_to ..., notice:`, `redirect_refused`; `my_sales_controller.rb` + `concerns/market/desk_loading.rb` + `views/market/my_sales/{show,_group}.html.erb` -- the tab screen, `markets/tab` wrapper, `row-focus`.
- `app/views/markets/_chips.html.erb` -- chips array; greyed `tabs__tab--disabled`. `app/frontend/styles/tabs.css` 74-83 (phone: equal-width chips), `market-screen.css`.
- `app/components/market_row_component.{rb,html.erb}` -- one rarity pill from `card.rarity`; `app/helpers/market_rows_helper.rb` (`row_amount`, `row_end`, `t("market.rows.labels.*")`).
- `app/views/market/cancellations/_dialog.html.erb` -- dialog markup to mirror; `ButtonComponent opens:`.
- `app/views/market/bids/_form.html.erb`, `app/frontend/controllers/{annonce,annonce_field,amount_field}_controller.ts`, `app/frontend/lib/{annonce,amount}.ts` -- the MON PRIX field model (text, `inputmode=numeric`, `amount-field` grouping, error `<p role="alert">`, `aria-invalid`, 500 ms `LIVE_DELAY` polite status, `submitting` flag reset on `turbo:submit-end`); `app/helpers/screen_wiring_helper.rb` (`screen_strings`).
- `app/views/cards/_detail.html.erb` 215-238 -- market group, links group (PARTAGER, VOIR SUR STEAM); `owned = !signed_in || copies.present?`; `CardsController#show` `market_state`.
- `app/views/market/_suspended_banner.html.erb`; `app/policies/market/{sale,my_bid}_policy.rb` (`player?`); a visitor refused by Pundit is redirected to `home_path` (the landing).
- `db/seeds.rb` 112-138 -- dev market seed pattern.
- Tests: `test/domains/game/market/place_bid_test.rb` (helpers `open_market!`, `close_market!`, `fund!`, `figures`, `nothing_changes`, `stub_singleton(Game::BankLock, :acquire, ->(*) { raise ActiveRecord::Deadlocked })`), `test/models/player_stream_test.rb`, `test/controllers/market/{sales,cancellations}_controller_test.rb` (throttle tests), `test/system/market_bids_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/market/order_rarities.rb` -- `OrderRarities.call(order_ids)` → `{ order_id => [rarity symbols in RARITIES order] }`, one `Order.where(id:).reaching(r).pluck(:id)` per rarity; never compares minimums itself.
- [x] `.../operations/game/market/place_order.rb` -- `call(player:, card_id:, price:, settings_token:)`: require_player, amount; in transaction: lock_bank, current_settings, published (`Catalog::PublishedCardIds.within([card_id])`), already open (`Order.where(player_id:, card_id:, status: "open").exists?`), `Order.create!(…, expires_at: settings.order_duration_days.days.from_now)`, `OrderRarities` empty → `:order_below_minimum`, available < price → `:more_than_available`, `Ledger.post` hold, `publish(OrderPlaced.about(order))`, returns order. Rescue `RecordNotUnique` → `:order_already_open`, Deadlocked → `:market_busy`.
- [x] `.../operations/game/market/cancel_order.rb` -- `call(player:, order_id:)`: require_player; transaction: lock_bank, `Order.lock.find_by(id:, player_id:)` (`:order_not_found`), status open else `:order_not_open`, `update!(status: "cancelled")`, `Ledger.post` release, publish `OrderCancelled`; no market check.
- [x] `.../queries/game/market/player_orders.rb` -- open orders of a player, `expires_at` asc: Row(token, card view, card slug, price, expires_at, rarities, duration_days); and `OrderIdByToken`-style lookup and `open_on(player, card_id)` for refusal values (in this file or a sibling).
- [x] `app/models/player_stream.rb` -- add OrderPlaced, OrderCancelled, OrderExpired, OrderWithdrawn, OrderServed, WantedChoicesApplied, ArchivePurchased, `Game::SlotBought` to `BALANCE_EVENTS`; branches for OrderServed (`buyer_id`, `seller_id`) and WantedChoicesApplied (`seller_id` + `sales.map { it[:buyer_id] }`) before the generic one.
- [x] `config/routes.rb` (additive) -- `get/post "market/order/cards/:slug"` → `market/orders#new/#create` (`new_market_card_order`, `market_card_orders`); `get "market/my-orders"` → `market/my_orders#show` (`market_my_orders`); `post "market/orders/:token/cancellation"` → `market/order_cancellations#create` (`market_order_cancellation`).
- [x] `app/policies/market/{order,my_order,order_cancellation}_policy.rb` -- `player?` (visitor → landing).
- [x] `app/controllers/market/orders_controller.rb` -- `new`: `CardDetail` by slug or 404, current settings (404 when none), `MarketState`, available; `create`: `throttle_player` (10/min), PlaceOrder with posted `price` and `settings_token`; success → `flash[:placed_order] = token`, `redirect_to market_my_orders_path, status: :see_other`; failure → `@refusal` with values (`amount:` available or lowest minimum, `rarity:` lowest rarity's name, `card:`/`amount:`/`days:` of the open order), `render :new, status: :unprocessable_content`, typed value kept, settings reloaded (token and minimums redrawn).
- [x] `app/views/market/orders/new.html.erb` (+ partials) -- `.page--regular`, top-bar title ORDRE D'ACHAT, h1 game title, h2 VOTRE ORDRE, "Toutes éditions de <card>…", MON PRIX field (empty on arrival, "Au moins <lowest>" beside), error `<p role="alert">` + `aria-invalid`, RARETÉS ATTEINTES chips (`aria-hidden`, both "<RARITY> <min>" ticked and "<RARITY> dès <min>" variants rendered, each rarity's minimum as data), the sentence, visually-hidden polite status, Bloqués maintenant, Durée "<n> jours", the free-cancellation sentence, PASSER L'ORDRE · <amount>, "Disponible : … Un ordre n'enchérit jamais à votre place."; hidden `settings_token`; suspended: banner, button disabled.
- [x] `app/frontend/lib/order_form.ts` + `order_form.test.ts` -- pure: `reachedRarities(minimums, price)`, `nextRarity`, `sentence(strings, minimums, price)` (variants: some reached + next price; all reached; none: next = lowest); vitest also runs the shared fixture.
- [x] `test/fixtures/files/order_reaching.json` -- minimums per rarity and `[{ price, reached }]` cases (below all, exact minimums, between, all); read by the vitest and a Ruby test creating orders through `Order.reaching`.
- [x] `app/frontend/controllers/order_form_controller.ts` -- root: on input update chips, sentence, Bloqués maintenant, button amount at once; post the sentence to the status after 500 ms without typing; Enter in the field focuses the button; one submit per activation (flag reset on `turbo:submit-end`).
- [x] `app/controllers/market/my_orders_controller.rb` + `app/views/market/my_orders/{show,_group,_result}.html.erb` -- `DeskLoading`, `markets/tab current: :orders`; result panel when `flash[:placed_order]` names one of the player's open orders: heading "ORDRE PASSÉ SUR <card>" focused, sentence, four facts (Raretés atteintes pills + words, Prix bloqué, Fin "<date> à <time>" + "<n> jours", Solde après "<amount> disponibles"), "Annulation sans frais. Un ordre n'enchérit jamais à votre place."; EN COURS rows via `MarketRowComponent` (title → order form, "toutes éditions", pills, EN COURS accent, Prix bloqué, Fin, ANNULER `secondary small` named "Annuler l'ordre, <card>" opening the dialog); empty → `EmptyStateComponent` "Vous n'avez passé aucun ordre.".
- [x] `app/controllers/market/order_cancellations_controller.rb` + `app/views/market/order_cancellations/_dialog.html.erb` -- `throttle_player` (20/min); token → id (404); CancelOrder; success `redirect_to market_my_orders_path, notice: "Ordre annulé : vos <amount> PiCoins vous sont rendus."`; failure `redirect_refused`. Dialog: "ANNULER CET ORDRE ?", "Vos <amount> PiCoins bloqués sur <card> vous sont rendus. Aucun frais.", GARDER L'ORDRE / ANNULER L'ORDRE.
- [x] `app/components/market_row_component.{rb,html.erb}` -- optional `rarities:` (pills with letter C/PC/R/É/L, full names for assistive tech) and `edition_note:` ("toutes éditions"); default unchanged.
- [x] `app/components/empty_state_component.{rb,html.erb}` -- `line:` plus optional `action` slot; `docs/design-system.md` row → exists.
- [x] `app/views/markets/_chips.html.erb` + `app/frontend/styles/` (tabs or market-screen css) -- fourth chip `[:orders, market_my_orders_path, t("market.chips.orders")]`, greyed for a visitor; phone: market chips one row scrolling sideways, right-edge fade, `scroll-margin-inline` so a focused chip clears the fade.
- [x] `app/views/cards/_detail.html.erb` (+ `CardsController` if a flag is needed) -- when the market is open (not suspended) and the viewer holds no edition (or is a visitor): `ButtonComponent` primary PASSER UN ORDRE → `new_market_card_order_path(slug: view.id)` before PARTAGER, disabled for a visitor; no other filled button on that detail.
- [x] `db/seeds.rb` -- development: two fake players each place one order via `PlaceOrder` on a published card they hold in no edition, at the lowest minimum; skip on failure, never twice.
- [x] `config/locales/en.yml`, `fr.yml` -- every new string; `errors.game.{card_not_published,order_below_minimum,order_already_open,order_not_open,order_not_found}` by hand; `market.chips.orders`; throttle alerts; French plurals with `zero`.
- [x] Tests -- `test/domains/game/market/{place_order,cancel_order,order_rarities}_test.rb` (every matrix row, entries carry `order_id`, cancel while closed, notice enqueued after commit); `test/models/player_stream_test.rb` (each new event); `test/controllers/market/{orders,my_orders,order_cancellations}_controller_test.rb` (visitor → landing, refusal keeps value with `aria-invalid`, 11th POST throttled, no id in HTML); `test/system/market_orders_test.rb` (Verify flow).

**Acceptance Criteria:**
- Given a signed-in player with 1,000 PiCoins on a card held in no edition, when they press PASSER UN ORDRE, type a price and PASSER L'ORDRE, then MES ORDRES shows the result panel (heading focused) and the order under EN COURS, and the balance chip shows the price committed.
- Given that order, when they press ANNULER and confirm in the dialog, then the cancelled status line shows, the row leaves EN COURS and the balance chip's available is back to 1,000.
- Given a visitor, when they open a card detail, then PASSER UN ORDRE is disabled and MES ORDRES greyed; when they GET the order form or MES ORDRES, then they land on the landing.
- Given the shared fixture, when vitest and the Ruby test run, then `reachedRarities` and `Order.reaching` agree on every case.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session verified and reviewed.
- `card_id:` keyword, refusal order and the insert-then-check of the reach as in Design Notes; `OrderRarities` settles entry 1's deferred `Order.reaching` item.
- French strings use U+202F before `:`, `;`, `?` (the typography test refused plain spaces); two chip-count assertions in `markets_controller_test` and `my_bids_controller_test` follow the fourth chip.
- A visitor on the bare card URL gets `cards/_public` (its filled button is the sign-in), so the greyed PASSER UN ORDRE shows only on the card detail a visitor reaches through a set or a profile.
- With an empty field, Bloques maintenant and the free-cancellation sentence read 0 and the button carries no amount; English pill letters are C/U/R/E/L.
- Local runs used a private database (`gameble_test_w46_2`) and `PARALLEL_WORKERS=4`; one full run was polluted by another lane writing the same database and was rerun.

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 41 findings — high 0, medium 4, low 30, false 4, maybe-false 3
- findings:
  - `[maybe-false]` `[defer]` blind: PlayerOrders drops an open order whose card has no published face, hiding held PiCoins — no catalog path unpublishes a season (no unpublish code under app/domains/catalog); settled by confirming card texts exist in both locales for every published card and seasons never leave `published`.
  - `[low]` `[reject]` blind: unknown token 404s while another player's token redirects "does not exist" — both say not found; a token is 24 random characters, nothing to enumerate.
  - `[low]` `[reject]` blind: a POST with no settings row 404s after the refusal — only before the first settings version exists, when the GET 404s too and no button leads there.
  - `[low]` `[reject]` blind: a never-opened market shows a disabled form with no banner — reachable only by typing the URL; the card detail hides the button until the market opens.
  - `[low]` `[reject]` blind: order_already_open copy can read "0 d" and is not pluralised — matches the Copy deck's "encore <n> j."; 0 only for a due order the expiry job (entry 9) sweeps within a minute.
  - `[false]` `[reject]` blind: the server does not refuse an order from a holder — the intent lists PlaceOrder's refusals and none is a holding; the detail only chooses where the button shows.
  - `[low]` `[patch]` blind: the phone chip fade covers the last chip at the scroll end — `padding-inline-end` the fade's width added to the phone chip row.
  - `[low]` `[patch]` blind: EmptyStateComponent's styles live in the orders stylesheet — moved to `app/frontend/styles/empty-state.css`.
  - `[low]` `[reject]` blind: rarity colours repeated in market-orders.css — no reader diverges today; a shared rarity token is the sweep's.
  - `[low]` `[reject]` blind: MarketRowComponent calls an orders helper for its pills — one caller; extracting a component adds surface for no named harm.
  - `[low]` `[reject]` blind: the order form view computes price, reach and lowest — view-local display values; moving them changes no behaviour.
  - `[low]` `[reject]` blind: the no-id-in-HTML test is weak — every route and DOM id uses tokens (read in the diff); the test is a backstop only.
  - `[low]` `[reject]` blind: CancelOrder deadlock / removed-player and some controller refusals untested — those matrix rows are covered by PlaceOrder's tests; CancelOrder's rescue is the shape CancelListing ships untested.
  - `[low]` `[patch]` blind: the server-drawn sentence can drift from the browser's — grouped with the French connector fix; the server sentence is now asserted after a refusal.
  - `[low]` `[reject]` blind: "0 PiCoins" before typing — the button hides its amount; the facts read 0 until a price is typed, recorded in Implementation Notes.
  - `[low]` `[reject]` blind: "%{amount} disponibles" not pluralised — the amount carries its unit; only a balance of exactly 1 reads oddly.
  - `[low]` `[reject]` blind: the seed picks two players the long way — development only, correct.
  - `[false]` `[reject]` blind: the plan file was not updated — the orchestrating session fills status, notes and results at finalize.
  - `[maybe-false]` `[defer]` edge: PlayerOrders drops orders whose card lost its face or locale text — same root as the first blind finding.
  - `[low]` `[reject]` edge: a due open order's row reads "Closing…" — transient until entry 9's expiry job, which runs every minute.
  - `[low]` `[reject]` edge: refusal reads "0 d left" for a due running order — same as the blind copy finding.
  - `[low]` `[reject]` edge: focus lands nowhere after a cancel — the flash status announces the release; the row is gone and the list may be empty, so no heading to land on.
  - `[false]` `[reject]` edge: holders can place orders by URL — same as the blind holder finding.
  - `[low]` `[reject]` edge: a price above 2^53 draws chips differently server and browser — such a price is refused as more than available before any chip matters.
  - `[low]` `[patch]` edge: the last chip stays under the fade — same fix as the blind fade finding.
  - `[maybe-false]` `[reject]` edge: overflow-x clips focus rings on the phone chip row — low if true; needs a phone-width render, noted as a residual risk.
  - `[medium]` `[patch]` edge: friend-holder "Propose" buttons are primary beside PASSER UN ORDRE, breaking its one-filled-button rule — they render secondary whenever PASSER UN ORDRE shows; a friend-holder case asserts one primary.
  - `[low]` `[reject]` edge: a visitor on the bare card URL never sees the greyed button — `cards/_public` is the visitor page whose one filled button is the sign-in; raised to the author.
  - `[medium]` `[patch]` verification-gap: order_form_controller has no vitest for the 500 ms status, Enter, one submit and refusal clearing — `order_form_controller.test.ts` added.
  - `[medium]` `[patch]` verification-gap: the server rarity words and sentence are never checked in French — French "et" connector from locale keys; French result-panel and server-sentence assertions added.
  - `[low]` `[patch]` verification-gap: nothing checks the row title links to the order form — `assert_select` added to the row test.
  - `[medium]` `[patch]` verification-gap: French rarity lists use English "and" (`to_sentence` without `fr.support.array`) — same fix as the French assertion finding.
  - `[low]` `[reject]` verification-gap: visitor on the plain card URL sees no order button — same as the edge visitor finding.
  - `[low]` `[reject]` intent: the greyed button reaches visitors only through set or profile browsing — same as the edge visitor finding.
  - `[false]` `[reject]` intent: PlaceOrder takes `card_id:` not `card:` — same behaviour, recorded in Design Notes.
  - `[low]` `[patch]` intent: the system test checks only the available figure, not the held amount on the chip — committed figure asserted after placing and after cancelling.
  - `[low]` `[reject]` intent: the live chip broadcast is never exercised in a browser — the intent has publishing stories test the notice; the enqueue after commit is asserted.
  - `[low]` `[reject]` intent: the sentence is tested on the fixture's minimums, not its cases — the fixture pins the reach, the one thing both sides compute.
  - `[low]` `[patch]` intent: the browser behaviours (Enter, one submit, polite status) are untested — same fix as the controller vitest finding.
  - `[low]` `[reject]` intent: card_not_published tested only with a card lacking any card-season — the unpublished-season case is PublishedCardIds' own, tested there.
  - `[low]` `[reject]` intent: "shown once" untested — the panel is driven by a one-request flash; a reload test would test Rails' flash.

### 2026-11-20 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 2, false 1, maybe-false 1
- findings:
  - `[low]` `[reject]` quick: a visitor on the bare card URL never sees the greyed PASSER UN ORDRE — carried: same claim as the earlier visitor rows; `cards/_public` is the visitor page, raised to the author.
  - `[low]` `[patch]` quick: on a phone the current chip no longer merges into the panel; `overflow-x: auto` turns its 2px overlap into clipped, vertically scrollable overflow — confirmed in a 360/390px render (panel border drawn under the current chip, row `scrollHeight` 48 over `clientHeight` 46); the phone row is now `overflow: auto hidden` with `padding-bottom` and a matching negative `margin-bottom` of `--space-unit`, so the chip covers the panel's edge again.
  - `[false]` `[reject]` quick: the result panel's lime label heading and its own edge and padding break the design system's heading and panel rules — DESIGN.md's "Order form result" specifies exactly this Bid result panel: lime edge, compact 12px 16px padding, heading bold 13px lime in label spacing.
  - `[maybe-false]` `[defer]` quick: PlayerOrders drops an open order whose card lost its face or locale text — carried: already the deferred item; not deferred again.
- phone render of the chip row (the named risk; 320, 360 and 390px, French and English, not a lens):
  - `[low]` `[patch]` render: on MES ORDRES the current chip arrives half past the row's edge ("MES ORDR" under the fade at 390px French) — the market tab controller scrolls the current chip clear of the fade when the chip row connects.
  - `[low]` `[patch]` render: tabbing to a partly visible chip leaves it under the fade (Chromium scrolls a focused element only when mostly hidden, so `scroll-margin-inline` never applies), against DESIGN.md's "a focused chip scrolls fully into view, its ring clear of the fade" — a `focusin` on the row scrolls the focused chip the same way.
  - The end padding works: scrolled to the end, the last chip stops 32px short of the edge, clear of the fade. Focus rings are inset and are not clipped.

## Design Notes

- `card_id:` rather than the architecture's `card:`: every market operation takes ids (`listing_id`, `card_season_id`), and the controller only holds `CardDetail#card_id`.
- Refusal order: closed, stale, unpublished, already open (query before insert, index as backstop), below minimum, more than available — the last two after the insert inside the transaction, so the reach is judged by `Order.reaching` on the saved row (entry 1's deferred item) and a `Failure` rolls the row back.
- The form's rarity computation is display only; the server decides through `OrderRarities`.
- Left open by the UX review, not built: a confirmation for a price far above the lowest rarity reached; a sign-in line under a visitor's greyed button.

## Verification

**Commands:** (all with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w46_2`)
- `bin/rails test` -- green
- `bin/rails test test/system/market_orders_test.rb test/system/market_bids_test.rb test/system/market_test.rb` plus the card detail system test file -- green
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` -- pass
- Do not commit or stage: the orchestrating session commits. Leave `package-lock.json` (another session's change) untouched. Other sessions use `gameble_test`; always export the private `DATABASE_URL` above (create it with `bin/rails db:create db:schema:load` under `RAILS_ENV=test` if missing).

## Auto Run Result

- **Summary:** buy orders end to end. `PlaceOrder` (bank lock; refuses closed, stale, unpublished, already open with the index as backstop, below every minimum and more than available after the insert so `Order.reaching` judges the saved row; one hold with `order_id`; `OrderPlaced`) and `CancelOrder` (bank lock then the row; release; `OrderCancelled`; allowed while closed). `OrderRarities` is the one reader of an order's rarities. `PlayerStream` gives a balance notice for every market-volume event. The Ordre d'achat screen (VOTRE ORDRE), MES ORDRES as the fourth market chip with the result panel, EN COURS rows and the cancel dialog, PASSER UN ORDRE on the card detail, `EmptyStateComponent`, a dev seed, copy in both locales.
- **Files:** operations `place_order.rb`, `cancel_order.rb`; queries `order_rarities.rb`, `player_orders.rb`, `order_id_by_token.rb`; `player_stream.rb`; controllers `market/{orders,my_orders,order_cancellations}_controller.rb` and their policies; views `market/{orders,my_orders,order_cancellations}/`, `cards/{_detail,show,_trade_section,_trade_holders,_trade_sheet}`, `markets/_chips`; `market_orders_helper.rb`; components `empty_state_component`, `market_row_component` (rarity pills, editions note); frontend `lib/order_form.ts`, `controllers/order_form_controller.ts` and their tests, `styles/{market-orders,empty-state,market-screen}.css`, `application.css`; `routes.rb`, `en.yml`, `fr.yml`, `db/seeds.rb`, `docs/design-system.md`; tests for the operations, the shared fixture `test/fixtures/files/order_reaching.json`, PlayerStream, four controller files and `test/system/market_orders_test.rb`; two chip-count tests.
- **Review:** 41 findings (high 0, medium 4, low 30, false 4, maybe-false 3). Patched 7 entries: 3 medium (French rarity list connector with French assertions; the order form controller's vitest; friend-holder Propose buttons secondary beside PASSER UN ORDRE) and 4 low (phone chip fade padding; empty-state stylesheet; row title link test; committed figure in the system test). Deferred 1 (PlayerOrders hiding an order whose card loses its face, unverified medium). Every rejected finding carries its reason in the triage log.
- **Follow-up review:** true. Three medium entries were patched. The unverified risk is the phone chip row (scrolling container, fade mask, end padding, the current chip's 1px overlap into the panel and focus rings), which no test renders at phone width.
- **Verification:** `bin/rails test` 6258 runs, 0 failures (private database, `PARALLEL_WORKERS=4`); system tests `market_orders`, `market_bids`, `market`, `card_detail`, `card_trade`, `market_sales` 14 runs green; `npm run test:js` 1539 green; `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing` pass. No migration.
- **Residual risks:** the deferred item; the phone chip row unchecked in a browser; a visitor on the bare card URL sees the public page without the greyed button; English copy and the C/U/R/E/L letters are drafts for the author; local `develop` is 10 ahead and 3 behind `origin/develop`, and those 3 commits also edit the locales and `player_streams/_update`.

### Follow-up review (2026-11-20, quick)

- **Summary:** the phone chip row, rendered at 320, 360 and 390px. The current chip merges into the panel again (`overflow: auto hidden`, `--space-unit` bottom padding and negative margin on the phone row). `market_tab_controller` scrolls the current chip clear of the fade when the row connects (MES ORDRES arrived half hidden), and the focused chip on `focusin` (browsers do not scroll a partly visible focused chip).
- **Files:** `app/frontend/styles/market-screen.css` (phone row overflow and overlap room); `app/frontend/controllers/market_tab_controller.ts` (`chipsTargetConnected`, `showChip`, `clearEdges`); `app/views/markets/_chips.html.erb` (`focusin` action); `test/system/market_orders_test.rb` (a 360px test: the current chip shows whole, clear of the fade, covers the panel's edge, no vertical scroll).
- **Review:** 4 lens findings (low 2, false 1, maybe-false 1) and 2 render findings. Patched 3 low entries (the merge, the current chip on arrival, the focused chip). Carried 1 reject (the visitor on the bare card URL) and 1 defer (PlayerOrders, already deferred). Rejected 1 false (the result panel follows DESIGN.md's Order form result).
- **Follow-up review:** false. No high was patched on this follow-up pass.
- **Verification:** system tests `market_orders`, `market`, `market_bids`, `market_sales`, `grand_inventory` and controller tests `markets_controller`, `market/my_orders_controller` 38 runs green (private database `gameble_test_w46_2r`, `PARALLEL_WORKERS=4`); `npm run test:js` 1539 green; `format:check`, `lint:css`, `check_planning_references`, `tsc` pass; `check_file_sizes` flags only `config/routes.rb` (401 lines), already over at fac0d398 and untouched here.
- **Residual risks:** the deferred item; rendered in headless Chromium only, not Firefox; the left edge has no fade, so a chip scrolled past it is cut hard.
