---
title: 'The order form shows what is for sale now and the order already placed'
type: 'feature'
ticket: '11'
created: '2026-11-23'
status: 'built'
baseline_revision: 'e9b9ce00730742e6bbf9bb9ab89b734b2c5bf4e6'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/docs/design-system.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Ordre d'achat screen built by the tracer shows only VOTRE ORDRE: a player cannot see the auctions already running on the game, the best price other players offer, or that a goal misses this card; with an order already open the form still offers a second one and only refuses at the press; MES ORDRES rows and the back button do not say where the form was opened from.

**Approach:** One query `Game::Market::CardListings` (the game's open listings, every edition, with seller) and one `Game::Market::BestVisibleOrder` (best other order's price, placed over an hour ago, never the viewer's, a removed owner's or a tied account's). The form gains DISPONIBLE MAINTENANT on the left (VOTRE ORDRE on the right, stacked on the phone), the goal head line, "Meilleur ordre en cours", the running-order line in place of the form, the closed line under the disabled button, and a back that names the screen it came from.

## Boundaries & Constraints

**Always:** GETs never write; tokens, never ids, in URLs/HTML/DOM; every string in `en.yml` and `fr.yml` (French as the Copy deck draws it, U+202F before `:` `;` `?`, plurals with `zero`); additive edits to locales; no planning ids; files ≤ 400 lines (Ruby/TS), 500 (CSS); markup server-rendered, no `style` attribute; ties read server-side only, never rendered; the best order shows a price only, never a name or token; follow `docs/design-system.md` (PanelComponent with its heading inside, `ButtonComponent variant: :link` for VOIR L'ANNONCE and MES ORDRES).

**Never:** the Archives' offer and ACHETER (entry 16); the "Ordre passé sur …, Carte i sur n" line and PASSER DES ORDRES chaining (entry 18); the market's empty-search PASSER UN ORDRE (entry 13); holding cancelled money for an hour (left open, epic boundary); changing `PlaceOrder`, `EligibleOrders` or the order form's Stimulus logic beyond what the running line needs; a migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Listings | two open listings on the game (any edition) | DISPONIBLE MAINTENANT: auction line, then one item each: "<Rarity> · S<n>", "Vendue par <PlayerName>", "Prix actuel <amount>", "<n> offres", time left, VOIR L'ANNONCE → Annonce, named "Voir l'annonce, <rarity> saison <n>, vendue par <name>, <amount> PiCoins"; ending soonest first | none |
| No listing | none open | "Personne ne vend <card> pour le moment. Un joueur qui en a un verra votre prix en le vendant ou en le confiant." | none |
| Goal | game missing from a goal of the viewer | head "Il vous manque cette carte pour <set>" with that goal's bookmark (lowest position) | none when held or in no goal |
| Best order | other open order ≥ 1 h old | "Meilleur ordre en cours" its price (max) | none |
| Best order none | only orders < 1 h, the viewer's own, a banned/deleted owner's, a tied account's, due or ended | "—", read "aucun" | none |
| Running order (GET) | viewer has an open order on the game | VOTRE ORDRE shows "Vous avez déjà un ordre sur <card> : <amount>, encore <n> j." and MES ORDRES ▸ instead of the form | none |
| Placed meanwhile | POST refused `:order_already_open` | same running line, focused (`tabindex=-1`, `autofocus`), 422 | nothing held |
| Suspended at press | POST refused `:market_closed` | banner, button disabled, the closed line under the button, focused | nothing held |
| Other refusal | e.g. `:more_than_available` | line under the field as today, now focused | unchanged |
| Back | `from=my_orders` / `from=card` / none | phone back "Mes ordres" → MES ORDRES / "Fiche" → card detail (history-back) / "Marché" → market | unknown `from` → market |

</intent-contract>

## Code Map

Backend (`app/domains/game/app/queries/game/market/`):
- `open_listings.rb` -- row shape (`Row token, card, current_price, ends_at, offers`), `OfferCounts.call(listing_ids)`, `Catalog::CardViews.call(card_season_ids, locale:)` (view has `rarity`, `season_number`, `title`). New `card_listings.rb`: `CardListings.call(card_id, locale:)` → `Listing.open_now.where(card_season_id: Catalog::CardSeason.where(card_id:).select(:id)).order(:ends_at, :id)`, Row adds `seller` (`Accounts::Player`, loaded by `where(id:).index_by`).
- `eligible_orders.rb` -- the `Order.open_at(now)` + `where.not(player_id: Accounts::Player.removed.select(:id))` idiom; `tied_accounts.rb` -- `TiedAccounts.call(player)` → ids. New `best_visible_order.rb`: `BestVisibleOrder.call(card_id, viewer:, now: Time.current)` → Integer price or nil; constant `VISIBLE_AFTER = 1.hour`; `Order.open_at(now).where(card_id:).where(created_at: ..(now - VISIBLE_AFTER)).where.not(player_id: [viewer.id, *TiedAccounts.call(viewer)]).where.not(player_id: removed).maximum(:price)`. Price only: never reaching, never owner.
- `player_orders.rb` -- `open_on(player, card_id)` gives the running order (price, `expires_at`). Unchanged.

Web:
- `app/controllers/market/orders_controller.rb` -- `include GoalMarksLoading` (`app/controllers/concerns/goal_marks_loading.rb`; `goal_marks.needs`, each Need has `position`, `missing_card_ids`, used with `GoalsHelper#goal_bookmark(position, size: :small)` and `goal_set_name(need)`); in `load_terms` add `@listings`, `@best_order`, `@running = PlayerOrders.open_on(...)`, `@goal = goal_marks.needs.find { it.missing_card_ids.include?(@detail.card_id) }`, `@from`; `create` keeps `@refusal_code = result.failure`; `running_order_values` moves to a helper usable by the view; for `:order_already_open` the view draws the running line instead of `@refusal`.
- `app/views/market/orders/new.html.erb` (62 lines) -- split: `new` (head, banner, a two-column wrapper), `_available.html.erb` (DISPONIBLE MAINTENANT panel), `_form.html.erb` (today's `form_with`, plus the "Meilleur ordre en cours" fact after Durée: price via `picoins`, or `<span aria-hidden="true">—</span><span class="visually-hidden">aucun</span>`; closed line `<p id="order-closed" class="market-bid__error" role="alert" tabindex="-1" autofocus>` under the button when `@refusal_code == :market_closed`; `#order-error` gains `tabindex="-1"` and `autofocus` when shown), `_running.html.erb` (`<p id="order-running" tabindex="-1" autofocus: refused>` + `ButtonComponent.new(variant: :link, href: market_my_orders_path)` "MES ORDRES"). Hidden `from` field in the form so a 422 keeps the back.
- Phone back today: `phone_back_link t("market.listings.show.back"), market_path`; card detail's uses `data: { controller: "history-back", action: "history-back#back" }` (`app/views/cards/show.html.erb` 9-13). `app/helpers/shell_helper.rb` `SCREEN_LABELS`: add `"market/orders" => :order`, `"market/my_orders" => :my_orders` (keys under `shell.screens`) so the desktop previous-screen button names them.
- `app/helpers/market_orders_helper.rb` (62 lines) -- add `order_back(from, card)` → `[label, path]`, `order_running_line(order, card_title)`, `order_listing_name(row)` (plain seller name: `t("player_name.anonymous")` when removed, else `Accounts::PersonaName.clean(persona_name) || t("shell.player.fallback_name")`); listing time with `MarketHelper#listing_time_left(listing_seconds_left(ends_at))`; offers with `t("markets.tile.offers", count:)`; rarity with `CardStrings.new.rarity_name`.
- `app/views/market/my_orders/_group.html.erb` -- row href `new_market_card_order_path(slug: row.card.id, from: "my_orders")`; `MarketRowComponent` already stretches the title over the row (`market-rows.css` `.market-row__title::after`), ANNULER the action sibling after it: keep.
- `app/views/cards/_detail.html.erb` 234 -- PASSER UN ORDRE href gains `from: "card"`.
- `app/frontend/styles/market-orders.css` (186 lines) -- add the columns (`display: grid`, one column under 720px, two from `@media (min-width: 720px)`, `gap: var(--space-stack-page)`), the listing items (no own border inside the panel), the goal head; or a new `market-order-available.css` imported in `app/frontend/entrypoints/application.css` beside `market-orders.css`. Tokens only.
- Copy (`config/locales/{fr,en}.yml`, `market.orders.new.*`, `shell.screens.{order,my_orders}`): "DISPONIBLE MAINTENANT" / "AVAILABLE NOW"; "Ce sont des enchères : pour les emporter, enchérissez sur l'annonce." / "These are auctions: to win one, bid on its listing."; "%{rarity} · S%{season}"; "Vendue par %{name}" (html) / "Sold by %{name}"; "Prix actuel" / "Current price"; "VOIR L'ANNONCE" / "SEE THE LISTING"; name "Voir l'annonce, %{rarity} saison %{season}, vendue par %{name}, %{amount} PiCoins" / "See the listing, %{rarity} season %{season}, sold by %{name}, %{amount} PiCoins"; nothing line as the matrix / "Nobody is selling %{card} right now. A player who has one will see your price when selling or entrusting it."; "Il vous manque cette carte pour %{set}" / "You are missing this card for %{set}"; "Meilleur ordre en cours" / "Best current order", "aucun" / "none"; running "Vous avez déjà un ordre sur %{card} : %{amount}, encore %{days} j." / "You already have an order on %{card}: %{amount}, %{days} d left." (same as `errors.game.order_already_open`); "MES ORDRES" / "MY ORDERS"; screens "Ordre d'achat" / "Buy order", "Mes ordres" / "My orders".

Tests to mirror: `test/controllers/market/orders_controller_test.rb` (helpers `place`, `open_market!`, `close_market!`, `fund!`; update "a second order on the card names the running one" to the running line), `test/support/market_listings.rb` `listing!(seller:, card_season:, current_price:)`, `test/support/market_orders.rb` `order!(player, card_season, price, created_at:)` and `buyer!`, `TiedAccount.create!(low_account:, high_account:, signal: "one_way_trades", facts: {}, refreshed_at:)` (lower id first), `test/domains/game/market/eligible_orders_test.rb` style, `test/system/market_orders_test.rb` (`sign_in_through_the_site`). Fixtures: card `common_card` "Tin Soldier" (`catalog_card_seasons(:common_card_one)`, slug `tin-soldier`), players `:player`, `:moderator`, `:administrator`, `:banned`. Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/queries/game/market/best_visible_order.rb` -- per Code Map.
- [ ] `app/domains/game/app/queries/game/market/card_listings.rb` -- per Code Map.
- [ ] `app/controllers/market/orders_controller.rb` -- goal, listings, best order, running order, `from`, refusal code.
- [ ] `app/views/market/orders/{new,_available,_form,_running}.html.erb` -- per Code Map and matrix; DISPONIBLE MAINTENANT first in the DOM (left on desktop, above on the phone), each column a `PanelComponent` with its h2 kicker inside; one primary button.
- [ ] `app/helpers/market_orders_helper.rb`, `app/helpers/shell_helper.rb` -- per Code Map.
- [ ] `app/views/market/my_orders/_group.html.erb`, `app/views/cards/_detail.html.erb` -- `from` on the links.
- [ ] `app/frontend/styles/` -- per Code Map; pass `npm run lint:css` and `npm run format:check`.
- [ ] `config/locales/en.yml`, `fr.yml` -- every new string.
- [ ] `test/domains/game/market/best_visible_order_test.rb` -- the best price of others' open orders over an hour old; skips under an hour, the viewer's own, a banned and a deleted owner's, a tied account's (either side of the pair), due and ended orders; nil with none.
- [ ] `test/domains/game/market/card_listings_test.rb` -- open listings of every edition of the card with seller, ending soonest first; other cards and ended listings absent.
- [ ] `test/controllers/market/orders_controller_test.rb` -- listings drawn with links to their Annonce (by token) and accessible names; nothing line; goal head when missing from a goal; best order price and "—"; running line instead of the field on GET and on a second POST (focused, 422); suspended POST draws the closed line under the disabled button; back label per `from`; no tied account's name or token in the HTML.
- [ ] `test/controllers/market/my_orders_controller_test.rb` -- the row title links to the order form with `from=my_orders`.
- [ ] `test/system/market_orders_test.rb` -- the Verify flow: a game with two listings shows both with their VOIR L'ANNONCE links; the player places an order; from the MES ORDRES row's title the form shows the running order line and MES ORDRES instead of the field.

**Acceptance Criteria:**
- Given a signed-in player on a game with two open listings, when they open the order form, then DISPONIBLE MAINTENANT lists both with their links, and VOTRE ORDRE shows the field.
- Given that player places an order, when they open the form again from their MES ORDRES row, then the running order's line and MES ORDRES show instead of the field and the button, and the phone back reads "My orders".
- Given another player's order placed two hours ago at 80 and a tied account's at 120, when the player opens the form, then "Meilleur ordre en cours" reads 80.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session read the diff and reran the checks.
- The running line reuses `errors.game.order_already_open` (the same copy) through `MarketOrdersHelper#order_running_line`; the controller no longer passes values for that refusal.
- `test/controllers/card_order_button_test.rb` follows the card detail's `from=card` link.
- `i18n-tasks unused` lists `shell.screens.{order,my_orders}`, like the other screen keys, since `screen_label_key` builds them.

## Plan Change Log

## Review Triage Log

## Design Notes

- The running order replaces the whole form (field, chips, facts, sentence, button, available line): those all describe a second order the screen refuses; the VOTRE ORDRE heading and its lead stay.
- The auction line sits above the listings ("under the line that they are auctions", ticket and EXPERIENCE.md), though the mock draws it after them.
- Several goals missing the card: the head names the lowest-numbered one.
- `from` is a plain query value read against a fixed list, never echoed raw.

## Verification

**Commands:** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_f PARALLEL_WORKERS=4`)
- `bin/rails test test/domains/game/market/best_visible_order_test.rb test/domains/game/market/card_listings_test.rb test/controllers/market/orders_controller_test.rb test/controllers/market/my_orders_controller_test.rb` -- green
- `npm run format:check`, `npm run lint:css`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing` -- pass
- System tests are written, not run (the caller runs them).
- Project root is `/home/teyermann/projets/gameble-mv-f` (a git worktree on branch `mv/f`); every path in this plan is relative to it. Start every shell command with `cd /home/teyermann/projets/gameble-mv-f &&`, call git as `/usr/bin/git`, and never read or write any other `/home/teyermann/projets/gameble*` directory (other builds run there). Create the test database with `RAILS_ENV=test bin/rails db:create db:schema:load` under the `DATABASE_URL` above if it is missing. Do not run system tests or the full suite; do not stage or commit.

## Auto Run Result

- **Summary:** the Ordre d'achat screen shows DISPONIBLE MAINTENANT (the game's open listings of every edition, each with edition, seller, current price, offers, time left and VOIR L'ANNONCE named per the Copy deck, or the nothing line) beside VOTRE ORDRE, stacked on the phone; the goal head line with its bookmark; "Meilleur ordre en cours" from `Game::Market::BestVisibleOrder` (others' open orders over an hour old, never the viewer's, a removed owner's or a tied account's; a price only, "—" read "aucun"); the running order's line and MES ORDRES in place of the form, focused when a POST is refused; the closed line under the disabled button when the market is suspended at the press; the back names MES ORDRES, the card detail or the market from `from`.
- **Files:** queries `best_visible_order.rb`, `card_listings.rb`; `market/orders_controller.rb`; views `market/orders/{new,_available,_form,_running}`, `market/my_orders/_group`, `cards/_detail`; helpers `market_orders_helper.rb`, `shell_helper.rb`; `market-orders.css`; `en.yml`, `fr.yml`; tests `best_visible_order_test.rb`, `card_listings_test.rb`, `orders_controller_test.rb`, `my_orders_controller_test.rb`, `card_order_button_test.rb`, `test/system/market_orders_test.rb`.
- **Review:** none (pinned by the author for this epic), no lenses launched.
- **Verification:** the five touched test files plus `card_order_button_test` 37 runs green and `test/config/` 64 runs green (private database `gameble_test_f`, `PARALLEL_WORKERS=4`); `format:check`, `lint:css`, `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing` pass. The new system test is written, not run. No migration.
- **Residual risks:** focus via `autofocus` on a `tabindex=-1` line after a 422 relies on Turbo and is unchecked in a browser; a POST refused as already open whose order ended meanwhile redraws the form with no line; the two-column layout is unrendered at phone and desktop widths; English copy is a draft for the author.

