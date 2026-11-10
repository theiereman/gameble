---
title: 'A seller lists a card from Mettre en vente'
type: 'feature'
ticket: '39.5'
created: '2026-11-10'
status: 'draft'
baseline_revision: '690c31e8394f5bbc1b94ffe3852097583d1fb622'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-listed-copy-shows-on-the-market-and-its-annonce-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `ListCard` exists but no screen calls it: a player cannot choose a copy, read the stamp, the commission and what they receive, or start an auction. Epic requirements R2 (the form half), R20 and R22 (listing rate limit, errors). Story 9's REMETTRE EN VENTE needs a form that takes prefill parameters.

**Approach:** A Mettre en vente screen with its own controller and policy, reached from the market screen and the card detail: a single-choice grid of free editions, then the form, its live lines computed in the browser for display only (`app/frontend/lib/listing_form.ts`) from the version's values in the markup and tested against `AuctionMath` through a shared fixture; the POST goes through `ListCard` behind a per-player throttle and lands on the new Annonce.

## Boundaries & Constraints

**Always:** the screen reads through a query and writes only through `ListCard`; the form submits the settings token it drew, and a stale token (`amounts_changed`) redraws the new amounts and keeps what was typed, charging nothing; `AuctionMath` stays the only authority, the browser computes display lines only; every refusal is a `Failure(:code)` shown through an `errors.game.<code>` key in both locales, in the Copy deck's words, inline at its field with `aria-invalid` and `aria-describedby`; no database id in a URL, the HTML, a DOM id or a stream name (a copy is `slug:season`, the Annonce its token); every amount through `PicoinAmountComponent`; the controller has its own Pundit policy; GET writes nothing; a visitor reads the screen with a sign-in panel and the POST answers `sign_in_required`; server HTML carries no `style` attribute and script builds no markup (it fills server-rendered `<template>`s and rewrites text); one root controller holds the state module, children talk by `dispatch`, the root drives them by outlets; the screen talks to the chrome only through the declared `gameble:*` events; all repo text in English, French only in `fr.yml`; no planning id in code, tests, config or migrations; no schema change; `db/schema.rb` untouched.

**Never:** the average price row (epic 41 inserts "Prix moyen" before the seller row), bidding, the suspended banner on the market screen (story 11; here the sale action is simply disabled while suspended), REMETTRE EN VENTE and its button (story 9, which only fills this story's prefill parameters), MES VENTES, a write outside `ListCard`, a second PiCoin amount component, a markup-building script, a React island, a planning id in code, a new migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Choose a card | Signed in, market open, free copies of several editions | Grid of one cell per edition with a free copy (card art, rarity, season, "n disponibles", minimum price), one tab stop, arrow keys move focus only, Space or Enter chooses, then the form shows that edition's minimum and stamp | — |
| One edition | Card detail slug page with a single free edition, or a prefill naming a ref | That edition is chosen; on the phone the second step shows alone | — |
| List | Chosen edition, start and optional buy-now at or above the minimum, a duration, enough `available` | `ListCard` success, redirect (303) to the new Annonce, h1 focused | `Success` |
| Live lines | Any start typed | Stamp ("payé maintenant, jamais remboursé"), commission ("10 % du prix final, à la vente"), "Vendue au prix de départ, vous recevez" with start minus commission, each recomputed per keystroke and posted once to the polite status region after 500 ms; empty or beyond safe integers shows no figure | — |
| Under the minimum | Start or buy-now below the rarity's minimum | Nothing written; "Au moins <amount> pour une <rarity>." under the field, amount kept | `start_below_minimum`, `buy_now_below_minimum` |
| Buy-now not above start | Buy-now at or under the start | Nothing written; "L'achat immédiat doit dépasser le prix de départ." | `buy_now_not_above_start` |
| Stamp short | `available` under the stamp | Nothing written; "Il vous manque <amount> PiCoins pour le timbre." with a CONFIER DES CARTES link | `stamp_not_covered` |
| Copy gone | Copy listed, traded or entrusted meanwhile, or unknown ref | Page redrawn without it; "Cette carte n'est plus disponible." | `copy_not_free` |
| Stale form | Settings token no longer current | New amounts drawn, typed values kept, nothing charged | `amounts_changed` |
| Closed | Market suspended | Form disabled, link back to the market; a POST is refused | `market_closed` |
| Busy | Deadlock | Inline "Archives busy" line, typed values kept | `market_busy` |
| Too many posts | 11th POST of a minute by one player | Redirect back to the form with the throttle alert | rate limit |
| Visitor | Signed out | Sign-in panel, no form; POST answers `sign_in_required` | Pundit refusal |
| No copy | Nothing free to list | "Aucune carte disponible à la vente." with OUVRIR UNE CAPSULE | — |
| Prefill | `ref`, `start`, `buy_now` and `relisting=1` in the query | Edition chosen, fields filled, a line says the amounts are the previous sale's | an unknown `ref` or a non-digit amount is ignored |

**Decisions (settled without a checkpoint, from the spec, architecture and UX):**
- Names: the screen is `Market::SalesController` (`new`, `create`) with `Market::SalePolicy` (`new?` true, `create?` player), apart from the Annonce's `Market::ListingsController` and `ListingPolicy`, which story 7 extends with bids. Routes: `GET /:locale/market/sell` (`new_market_sale`), `GET /:locale/market/sell/cards/:slug` (`new_market_card_sale`, a card's editions, as Confier's), `POST /:locale/market/sell` (`market_sales`); no conflict with `market/listings/:token`.
- Prefill contract for story 9: query parameters `ref` (`slug:season`), `start`, `buy_now` (digits only) and `relisting=1`; the form's POST fields are `ref`, `starting_price`, `buy_now_price`, `duration_hours`, `settings`.
- The reader is a new query `Game::Market::SellableCopies` (one row per edition with a free copy and a rarity, with its `CardView`), not `EntrustableCopies`, which carries entrustment values and no card art; `EntrustableCopies.resolve` is reused to turn refs into card-season ids.
- The card detail's METTRE EN VENTE reuses `CardEntrustment` (free and reserved of the card, nil before the first opening, while suspended and for a visitor): absent for nil, greyed with the existing "n exemplaires réservés" note when `free` is zero, else a secondary link to `new_market_card_sale_path(slug:)`; the note shows once for both buttons.
- The market screen's actions are CONFIER DES CARTES (secondary) then METTRE EN VENTE (primary, lime); each carries a short label (CONFIER, VENDRE) that replaces the long one under 720 px, the accessible name staying the long label. For a visitor both are greyed buttons; while suspended METTRE EN VENTE is disabled (its banner reason is story 11's).
- The browser computes `commission = floor(price * basis_points / 10 000)` with `BigInt` for the product and shows no figure for an amount beyond `Number.MAX_SAFE_INTEGER` (the server still decides): one shared fixture, `test/fixtures/files/listing_amounts.json` (rows: price, basis points, commission, received as strings), is read by Vitest against `commission` and by the Ruby test against `AuctionMath.commission`.
- Client refusals mirror the three price rules and show at submit, clear on the next edit, and block the submit; the server answers the same refusals for a browser with no script. The commission percentage text is rendered by the server (`commission_basis_points / 100`, "2,5" in French) into the markup; the browser never formats a percentage.
- The button reads "METTRE EN VENTE · <stamp>": the amount in it is the stamp, the only PiCoins charged now; the status region says "Vous recevez <amount> PiCoins".
- Enter in the start field moves to the buy-now field, in the buy-now field to the checked duration, in the duration to the button; Enter never submits; the form is a plain (`turbo: false`) post, as Confier's, so the Annonce loads fresh with its h1 focused.
- Phone: two steps ("Étape 1 sur 2"), the second with a back link to the grid; desktop shows the grid and the form side by side, the form dimmed and inert until an edition is chosen; layout read through the same phone media query as Confier's.
- A refusal that redraws the page (stale, copy gone, stamp, busy) re-renders `new` with status 422 and the posted values; `stamp_not_covered`, `start_below_minimum` and `buy_now_below_minimum` interpolate `amount` and `rarity` from the settings in force, so their `errors.game` texts take those placeholders (reworded to the Copy deck).
- Rate limit: `throttle_player to: 10` per minute on `create`, as Confier's, redirecting to the form with `market.sales.create.throttled`.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/list_card.rb` -- the writer: `call(player:, card_season_id:, starting_price:, buy_now_price:, duration_hours:, settings_token:)` returns `Success(listing)` with `listing.token`; failures `market_closed`, `amounts_changed`, `no_rarity`, `copy_not_free`, price, duration, `stamp_not_covered`, `market_busy`; `failure_message(code, **values)` interpolates.
- `app/domains/game/app/models/game/market/auction_math.rb`, `settings.rb` -- `commission(price, basis_points)`; `stamp(rarity)`, `minimum_price(rarity)`, three durations, `preselected_duration_hours`, `commission_basis_points`, `token`.
- `app/domains/game/app/queries/game/market/entrustable_copies.rb` -- model for the SQL and `resolve(refs)` (reused); `card_entrustment.rb` -- free and reserved per card, nil unless open; `balance.rb`, `current_settings.rb`, `market_state.rb`.
- `app/domains/catalog/app/queries/catalog/card_views.rb` -- `CardViews.call(ids, locale:)` for the grid's card art.
- `app/controllers/market/entrustments_controller.rb`, `app/policies/market/entrustment_policy.rb`, `app/views/market/entrustments/*` (`new`, `_grid`, `_cell`, `_recap`, `_bar`, `_sheet`), `app/helpers/market_entrustments_helper.rb`, `app/helpers/screen_wiring_helper.rb` -- the closest model: closed, suspended and sign-in panels, root-and-outlets wiring, the 422 redraw keeping the posted values, the throttle.
- `app/frontend/controllers/entrust_controller.ts`, `entrust_grid_controller.ts`, `entrust_recap_controller.ts`, `app/frontend/lib/entrust.ts`, `entrust_view.ts`, `entrust_layout.ts` (`PHONE_QUERY`), `grid_keys.ts` (`columnsOf`, `nextIndex`), `picoins.ts`, `i18n.ts` (`t`) -- the model of a rich screen's state module, views, phone layout, grid keys, amount and string helpers.
- `app/components/picoin_amount_component.rb` (`.picoin-amount__figure`), `card_component.rb` (size s), `button_component.rb`, `panel_component.rb`; `app/views/shell/_balance_chip.html.erb`.
- `app/views/markets/screen.html.erb`, `app/controllers/markets_controller.rb` -- the action row to extend; `app/views/cards/_detail.html.erb` (lines 194-203, `card-detail__market`) and `cards_controller.rb` (`@entrustment`) -- the card detail's action rows.
- `app/helpers/shell_helper.rb` (`SCREEN_LABELS`), `config/routes.rb` (market routes), `app/frontend/entrypoints/application.css`, `app/frontend/styles/market-entrust*.css`, `market-screen.css` -- placement, screen title, styles.
- `test/controllers/market/entrustments_controller_test.rb` (incl. the throttle test with `with_counting_rate_limit`), `test/domains/game/market/entrustable_copies_test.rb`, `list_card_test.rb`, `auction_math_test.rb`, `test/helpers/picoins_helper_test.rb` and `app/frontend/lib/picoins.test.ts` (shared fixture reading), `test/system/market_entrust_test.rb`, `test/support/market.rb`, `holdings.rb`, `market_listings.rb`.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (Mettre en vente, Settings behind an open form, Copy deck "Mettre en vente" and "Market refusals", State Patterns, Accessibility Floor "Market", Focus after each step) and `DESIGN.md` (Marché: Confier and Mettre en vente grids, Mettre en vente) -- copy and look.

## Tasks & Acceptance

**Execution:**
- [ ] `test/fixtures/files/listing_amounts.json` -- create the shared rows (price, basis points, commission, received; amounts as strings; prices 0 to 9_007_199_254_740_991 and beyond, basis points 0, 250, 1000, 2500) -- one source for both sides.
- [ ] `app/domains/game/app/queries/game/market/sellable_copies.rb` -- create `SellableCopies.call(player, locale:, card_slug: nil)` returning `Copy = Data.define(:ref, :card, :free, :reserved)` (card is a `Catalog::CardView`), one per edition with `quantity > reserved` and a rarity, rarest first then season, title, ref; a copy whose card has no view in the locale is left out; `ref` is `"slug:season"` -- the screen's one reader.
- [ ] `config/routes.rb` -- add the three market sale routes beside the entrust ones -- the addresses.
- [ ] `app/policies/market/sale_policy.rb`, `app/controllers/market/sales_controller.rb` -- create: `include PublicRead`; `new` loads settings, state, copies (a `:slug` filters one card, an unknown slug 404s as Confier's), the prefill (`ref` kept to listed refs, digit-only `start` and `buy_now`, `relisting`), preselects when exactly one edition is listed; `create` resolves `ref` with `EntrustableCopies.resolve`, calls `ListCard`, redirects 303 to `market_listing_path(token)`, or redraws `new` with 422, the refusal's code, its message (`failure_message` with `amount` and `rarity`) and the posted values; the throttle `to: 10`; an unresolved ref is `copy_not_free` -- the web layer, no model written.
- [ ] `app/helpers/market_sales_helper.rb` -- create `sale_root_data` (controller, actions and outlets through `screen_actions`/`screen_outlets`, locale, strings from `market.sales.strings`, commission basis points and percent text, settings values), `sale_cell_label(copy)` (name, rarity, season, state, minimum), `sale_durations(settings)` with "12 H", "24 H", "3 JOURS" labels and the preselected one -- the markup helpers.
- [ ] `app/views/market/sales/new.html.erb`, `_grid.html.erb`, `_cell.html.erb`, `_form.html.erb`, `_summary.html.erb` -- create: header with the Balance chip, "Étape 1 sur 2" on the phone, the sign-in, closed, suspended (the shared banner, form disabled, link to the market), empty and refusal states; the grid (`role="listbox"`, one tab stop, cells `role="option"` with `aria-selected`, card art at size s on a sunken cell, "n disponibles", minimum and stamp as data attributes), the form (hidden `settings` and `ref`, `starting_price` with "Au moins <amount> pour une <rarity>", optional `buy_now_price` "facultatif", the duration radios with the preselected one, text inputs `inputmode="numeric"` `autocomplete="off"`, the rules text "La carte est réservée pendant la vente. Vous pouvez annuler tant qu'aucune offre n'est en tête.", the submit "METTRE EN VENTE · <stamp>"), the summary lines with their `PicoinAmountComponent`s and a hidden polite status region; `data-turbo="false"`; no `style` attribute -- the screen.
- [ ] `app/frontend/lib/listing_form.ts` -- create the pure state module: `start`, `choose`, `setStart`, `setBuyNow`, `setDuration`, `step` and layout transitions, `commission(price, basisPoints)` with `BigInt`, `received`, `refusal(state)` for the three price rules, `lines(state)` for stamp, commission and received; no DOM -- the rules and display math.
- [ ] `app/frontend/lib/listing_form_view.ts` -- create the pure view derivation (cell and field states, line texts through `t()` and `picoins()`, the status sentence) -- keeps files under 400 lines.
- [ ] `app/frontend/controllers/listing_form_controller.ts`, `listing_grid_controller.ts`, `listing_fields_controller.ts`, `listing_summary_controller.ts` -- create the root (reads values and cells, holds the state, drives the children through outlets, watches `PHONE_QUERY`, blocks the submit while `refusal` is set) and three children that only dispatch (`chosen`, `typed`, `entered`, `duration`) and render what the root gives: roving tabindex with `grid_keys`, Space or Enter choosing, Enter moving to the next field, inline refusals with `aria-invalid`, the status region posting after 500 ms without typing and never an unchanged text; focus after choosing moves to the start field on the phone's second step -- the behaviour.
- [ ] `app/frontend/lib/listing_form.test.ts`, `listing_form_view.test.ts` -- test every fixture row against `commission` and `received`, the three refusals, the beyond-safe-integer case, the transitions and the status sentence -- the module's checks.
- [ ] `app/frontend/styles/market-sale.css`, `market-sale-phone.css`, `app/frontend/entrypoints/application.css` -- create and import: tokens only; grid cells, lime frame and check on the chosen cell, the form beside the grid on desktop, two steps and the bar pinned only from 560 px of viewport height on the phone, ruled fee lines with the Brotherhood's names in italics, the received amount in gold; each file under 500 lines, `npm run lint:css` clean -- the look.
- [ ] `app/views/markets/screen.html.erb`, `app/controllers/markets_controller.rb`, `app/frontend/styles/market-screen.css` -- add METTRE EN VENTE (primary link to `new_market_sale_path`, a greyed button for a visitor, disabled while suspended) with the short labels on the phone and the actions on a row of their own -- the market's entry point.
- [ ] `app/views/cards/_detail.html.erb`, `app/frontend/styles/card-detail.css` -- add the secondary METTRE EN VENTE beside CONFIER from the same `entrustment` state, the reserved note once -- the card detail's entry point.
- [ ] `app/helpers/shell_helper.rb` -- add `"market/sales" => :market` to `SCREEN_LABELS` -- the screen's title.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- add `market.sales.new.*`, `market.sales.strings.*` (client templates), `market.sales.create.throttled`, `markets.screen.sell`, `markets.screen.sell_short`, `markets.screen.entrust_short`, `card_details.list.button`; rewrite `errors.game.start_below_minimum`, `buy_now_below_minimum`, `buy_now_not_above_start`, `copy_not_free` to the Copy deck's words with `%{amount}` and `%{rarity}` where it says so, and keep the dynamic `errors.game` keys by hand; alphabetical, French plurals with `zero`, `bundle exec i18n-tasks` clean -- all copy in both languages.
- [ ] `test/domains/game/market/sellable_copies_test.rb`, `auction_math_test.rb` -- the query (free editions only, no rarity left out, only copy listed, reserved copy excluded, slug filter, no database id in a row); `auction_math_test.rb` reads the shared fixture against `AuctionMath.commission` -- the reader and the shared check.
- [ ] `test/controllers/market/sales_controller_test.rb`, `test/helpers/market_sales_helper_test.rb` -- new (cells per edition, card slug page, one edition preselected, prefill and ignored bad prefill, empty state, closed and suspended, visitor panel, GET writes nothing, no database id in markup), create (success redirects to the Annonce and the listing, stamp entry and reservation exist; start under the minimum, buy-now rules, stamp short with its link, copy gone, unknown ref, stale version redrawing the new token and keeping typed values with nothing charged, busy via a stubbed deadlock, closed), a visitor POST refused with `sign_in_required`, the eleventh POST throttled; durations and labels -- the web layer.
- [ ] `test/controllers/markets_controller_test.rb`, `test/controllers/cards_controller_test.rb` -- METTRE EN VENTE on the market (player, visitor greyed, suspended disabled) and in the card detail (absent before the opening, while suspended and for a visitor; greyed with the reserved count; link otherwise) -- the entry points.
- [ ] `test/system/market_listing_test.rb` -- a player lists a copy from the card detail at 24 H with a buy-now, lands on the Annonce with its h1 focused and finds the tile on the market; a start under the minimum is refused inline keeping the amount; retrying matchers only, any window-size change restored -- the end-to-end check.

**Acceptance Criteria:**
- Given a player with free copies of several editions, when they open Mettre en vente, then one cell per edition shows, the grid is one tab stop, arrows only move focus and Space or Enter chooses, and only then do the form and its minimum change.
- Given the form, when the start or buy-now changes, then the stamp, commission and received lines follow, the displayed commission equals `AuctionMath.commission` on every row of the shared fixture, and one short status posts after 500 ms without typing.
- Given a valid form, when it is submitted, then `ListCard` runs once, the player lands on the new Annonce with its h1 focused and the tile shows on the market, and Enter in any field never submits.
- Given a start under the minimum, a buy-now not above the start or a short stamp, when submitted, then the refusal shows inline in the Copy deck's words, the typed amounts stay and nothing is charged.
- Given the settings changed after the form was drawn, when it is submitted, then nothing is charged or reserved, the new amounts are drawn and what was typed is kept.
- Given a visitor, when they open it, then they read a sign-in panel, and a POST answers `sign_in_required`; given an eleventh POST in a minute, then it is throttled.
- Given a fully reserved card, when its detail shows, then METTRE EN VENTE is greyed with "n exemplaires réservés"; before the first opening, while suspended and for a visitor it is absent.
- Given a prefill `ref`, `start` and `buy_now`, when the form opens, then the edition is chosen and the fields are filled with the relisting line.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The root drives its children and they only report:

```ts
// listing_grid_controller.ts
choose(event: Event): void { this.dispatch("chosen", { detail: { ref: cellOf(event).dataset.ref } }) }
// listing_form_controller.ts
chosen(event: Intent<{ ref: string }>): void { this.state = choose(this.state, event.detail.ref); this.render() }
```

Shared fixture row: `{ "price": "1300", "basisPoints": 1000, "commission": "130", "received": "1170" }`.

## Verification

**Commands:**
- `bundle exec rubocop` on every touched Ruby file; `ruby -c` on each new one -- expected: no offense, Syntax OK
- `bundle exec packwerk check` -- expected: no violation
- `script/check_planning_references`, `script/check_file_sizes` -- expected: clean
- `/home/teyermann/projets/gameble/node_modules/.bin/prettier --write` on the touched frontend files, `npm run lint:css` -- expected: formatted, clean
- run once at the end of the market run: `bin/rails test test/domains/game/market test/controllers/market test/controllers/markets_controller_test.rb test/controllers/cards_controller_test.rb test/helpers`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks health`, `bin/rails test test/system/market_listing_test.rb`

**Manual checks (if no CLI):**
- With the market open, METTRE EN VENTE on `/en/market` and on a card detail opens the grid; choosing an edition shows its minimum, the lines follow the amounts, and a successful listing lands on the Annonce.
