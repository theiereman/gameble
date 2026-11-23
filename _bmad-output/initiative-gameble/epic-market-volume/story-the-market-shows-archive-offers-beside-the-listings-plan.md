---
title: 'The market shows Archive offers beside the listings'
type: 'feature'
ticket: '16'
created: '2026-11-23'
status: 'built'
baseline_revision: 'f824bca0c6ffc6e0b8e3c39b4780ae5bd394784d'
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

**Problem:** The Archives' shop exists only at its own URL: ANNONCES has no shop panel, its grid shows player listings alone, a search for a game nobody sells offers no way to place an order, and the order form shows nothing to buy when the game has no listing although the Archives hold it.

**Approach:** On ANNONCES, a Shop panel above the listings (count, line, four featured Archive offer tiles, "Voir toute la boutique ▸"); one grid query, `Game::Market::MarketGrid`, mixing open listings and priced Archive stock in SQL (`UNION ALL`) under the chosen sort and page; the search's one-game empty states with PASSER UN ORDRE; the order form's Archives lines when the game has no open listing. Every ACHETER opens the existing purchase confirmation dialog.

## Boundaries & Constraints

**Always:** reads only (no migration, no operation, no event); prices from the settings version through `ArchiveOffers` (never constants); a rarity whose Archive price is null is absent everywhere; tokens and slug/season refs only, never ids, in URLs, HTML and DOM ids; every string in `en.yml` and `fr.yml` (French as the Copy deck draws it, English beside it; French plurals with `zero`; U+202F before `:` `;` `?` `!`); "Voir toute la boutique ▸" is `ButtonComponent variant: :link`; server-rendered markup only, script clones server templates, no `style` attributes; no planning ids; files ≤ 400 lines Ruby/TS, ≤ 500 CSS; follow `docs/design-system.md` (panel heading inside, h2 kickers).

**Never:** a change to `BuyFromArchives`, the confirmation, or the shop screen beyond the `_offer` partial's new locals; leaving the panel's offers out of the grid; sorting by week; live refresh; the "Ordre passé sur … Carte i sur n" line (entry 18); a stock count on market tiles.

**Decisions on the ticket's `unknown` (settled by EXPERIENCE.md, Market screen row, author 2026-11-20):** the grid mixes Archive offers "under the chosen sort" with no exception, so its first rows keep offers the panel also shows; "les plus récentes" orders offers "by the day the copy joined the Archives" (accepted 2026-11-20), so by day, not week.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Panel | priced stock of 5 editions, viewer wants one | count "<n> cartes aux Archives" (distinct cards), the wanted edition first, then by entrusting day desc, then card-season; 4 tiles (CSS hides the 4th under 720px); link "Voir toute la boutique ▸" under the frame | none |
| Panel empty | no stock, or no rarity priced | count 0, `EmptyStateComponent` "Aucune carte aux Archives pour le moment.", no link | none |
| Panel visitor / suspended | no player, or market suspended | tiles link to the card detail, no "ACHETER ▸"; no dialog drawn | none |
| Sort price_asc / price_desc | listings 80, 300; offer 100 | 80, 100, 300 / 300, 100, 80; ties: listing before offer, then id / card-season | none |
| Sort ending (default) | same | listings by `ends_at`, then offers by price asc | none |
| Sort newest | listings created today and 3 days ago; offer deposited (latest deposit `updated_at`) 2 days ago | today, offer, 3 days ago; offers keyed by `date_trunc('day', MAX(deposits.updated_at))` | none |
| Paging | more than 24 mixed rows | 24 per page, `more` true, page 2 continues the same order | none |
| Filters | q, rarity, season, sets, genre, wanted, min/max price | apply to offers too (price bounds on the fixed price); `hide_mine` applies to listings only | none |
| Search count | `q` matching 3 listings and 3 offers | note "3 annonces · 3 cartes des Archives" ("1 annonce", "1 carte des Archives"; the Archives part left out at 0) | none |
| One game, nothing | `q` naming one published catalog game, no listing, no offer | `EmptyStateComponent` "Aucune annonce pour <card>." + PASSER UN ORDRE (secondary) to `new_market_card_order_path(slug:)` | disabled for a visitor or a suspended market |
| One game, offers only | same, offers present | line "Aucune annonce de joueur pour <card>." + PASSER UN ORDRE above the grid of offers | same |
| Several or no games | `q` matching 0 or ≥ 2 games | the existing empty lines | none |
| Order form, no listing | game held by the Archives in two priced editions | under DISPONIBLE MAINTENANT: "Aucune annonce de joueur pour <card>.", one line per edition by price: "<Rarity> · S<n>", ARCHIVES tag, "prix fixe" <amount>, "ACHETER · <amount>" opening the confirmation dialog, named "Acheter aux Archives, <card> <rarity> saison <n>, <amount> PiCoins" | ACHETER disabled when suspended |
| Order form, listings | game has an open listing | listings only, no Archives lines | none |

</intent-contract>

## Code Map

- Worktree: every path is under `/home/teyermann/projets/gameble-mv-k` (branch `mv/k`). Work only there; start every shell command with `cd /home/teyermann/projets/gameble-mv-k &&`; call git only as `/usr/bin/git`; never stage, commit or push.
- `app/domains/game/app/queries/game/market/archive_offers.rb` -- `offers(settings, filters, locale)` (stock ⋈ card-seasons, priced tiers, `filters.apply`), `price_sql(settings)`, `priced_tiers`, `build`, `Row(card, price, stock)`, `Counts(cards, editions)`. Make `offers`/`price_sql` usable by `MarketGrid` (public, renamed if clearer); add `entrusted_day_sql` (`(SELECT date_trunc('day', MAX(d.updated_at)) FROM game_market_archive_deposits d WHERE d.card_season_id = game_market_archive_stocks.card_season_id)`, index on `card_season_id` exists), `featured(settings:, wanted_card_ids:, locale:, limit: 4)` (wanted card first, entrusting day desc, card-season asc) and `for_card(settings:, card_id:, locale:)` (price asc, card-season asc). `ListingFilters#apply` reads `current_price`/`seller` for price and hide-mine: for offers pass `filters.with(min_price: nil, max_price: nil, hidden_seller: nil)` and bound `price_sql` yourself.
- `.../open_listings.rb` -- `ORDERS`, `DEFAULT_SORT`, `Row(token, card, current_price, ends_at, offers)`, `OfferCounts.call(ids)`, `count`. Keep it; other screens use it.
- New `.../market_grid.rb` (`Game::Market::MarketGrid`): `call(settings:, sort:, page:, locale:, filters:)` → `OpenListings::Page`-shaped `Page(rows, more)`, rows `OpenListings::Row` or `ArchiveOffers::Row` in order; falls back to `OpenListings.call` when settings is nil or nothing is priced. One `UNION ALL` of listings (`kind 0, id, token, card_season_id, current_price AS price, ends_at, created_at AS listed_at, NULL stock`) and offers (`kind 1, card_season_id AS id, NULL token, card_season_id, price_sql, NULL ends_at, entrusted_day_sql, quantity`), ordered per the matrix, `PER_PAGE = 24`, one extra row for `more`; `offers_count(settings:, locale:, filters:)` (editions matching). Cast NULL columns so both branches type-match.
- `.../listing_filters.rb` -- add public `searched_card(locale)` → the card-season id (latest published) when `query` matches exactly one card among published seasons with a rarity, else nil; reuse the private `title_match`.
- `app/controllers/markets_controller.rb` (63 lines) -- load `@settings = Game::Market::CurrentSettings.call`, `MarketState.call(@settings)`, `@buyable = current_player.present? && state.open?`; `@listings = MarketGrid.call(...)`; stands from listing rows only; html: shop panel (`@shop_offers`, `@shop_count`, `@shop_marks` via `ListingMarks.for`), `@found_offers` with filters, `@searched` (a `Catalog::CardViews` view) when `query` present and `@found` is 0. Keep ≤ 400 lines; a concern `Market::ShopPanelLoading` is fine if it reads better.
- Views: `app/views/markets/screen.html.erb` (panel first in the tab content; heading note; one-game line above the grid; root `data-controller="next-page purchase-dialog"`; `render "market/shops/dialog" if @buyable`), `screen.turbo_stream.erb` and `_tiles.html.erb` (render `market/shops/offer` for `ArchiveOffers::Row` with `stock: false`, `tile_id: false`, `buyable:`), `_empty.html.erb` (one-game branch first, `EmptyStateComponent` with its action), new `_shop_panel.html.erb` (pattern: `_wanted_panel.html.erb`), new `_order_prompt.html.erb` if shared.
- `app/views/market/shops/_offer.html.erb` -- add locals `size: :m` (CardComponent size) and `tile_id: true` (no `id` attribute when false: the purchase stream replaces the shop tile by that id; market tiles must not collide with it). `app/helpers/archive_shop_helper.rb#archive_offer_label` already takes `stock:`.
- `app/views/market/shops/_dialog.html.erb` + `app/frontend/controllers/purchase_dialog_controller.ts` -- reuse unchanged: links carry `data-turbo-frame="archive-purchase"` and `data-action="purchase-dialog#open"` inside an element with `data-controller="purchase-dialog"` that also holds the dialog.
- `app/controllers/market/orders_controller.rb#load_terms` -- `@archive_offers = @listings.empty? ? ArchiveOffers.for_card(...) : []`; `@buyable = !@suspended`. `app/views/market/orders/{new,_available}.html.erb` -- section gets `data-controller="purchase-dialog"`, dialog rendered when open and offers exist; Archives lines per the matrix. `ButtonComponent` (`app/components/button_component.rb`, `.html.erb`) lacks `data:`: add a `data:` option merged into the link's data (keep `turbo_frame:`).
- CSS: `app/frontend/styles/market-shop.css` (171 lines) -- shop panel: frame `box-shadow: inset 0 0 0 2px var(--color-archives)` on `--color-panel`, heading row with muted label count, the line `--font-body-small` muted, four tiles in one row 24px apart at `card-s`, `:nth-child(4)` hidden under 720px, foot link right-aligned (mirror `.wanted-panel__foot` in `market-wanted.css`); order-form Archives lines (mirror `.order-listing` in `market-orders.css`). Tokens only.
- Locales (fr ~2968 `markets:`, en ~3940; `market.shops.*` fr ~2480; `market.orders.new.*` fr ~2760): `markets.shop_panel.{heading "BOUTIQUE DE LA CONFRÉRIE", count (zero/one "%{count} carte aux Archives", other "… cartes aux Archives"), line "Les Archives revendent les cartes confiées, à prix fixe.", see_all "Voir toute la boutique ▸", see_all_label "Voir toute la boutique de la Confrérie", list_label}`; `markets.screen.{found_listings (n annonce(s)), found_archives (n carte(s) des Archives), no_listing "Aucune annonce pour %{card}.", no_player_listing "Aucune annonce de joueur pour %{card}.", place_order "PASSER UN ORDRE"}`; `market.orders.new.{archives "ARCHIVES", fixed "prix fixe", buy "ACHETER · %{amount}", buy_label "Acheter aux Archives, %{card} %{rarity} saison %{season}, %{amount} PiCoins", no_player_listing}`. English beside ("SHOP OF THE BROTHERHOOD", "%{count} cards in the Archives", "The Archives resell entrusted cards at a fixed price.", "See the whole shop ▸", "%{count} listings", "%{count} Archive cards", "No listing for %{card}.", "No player listing for %{card}.", "PLACE AN ORDER", "fixed price", "BUY · %{amount}").
- Tests to mirror: `test/domains/game/market/{archive_offers,open_listings,listing_filters}_test.rb`, `test/controllers/markets_controller_test.rb`, `market_filters_test.rb`, `market_wanted_panel_test.rb`, `test/controllers/market/{orders,shops}_controller_test.rb`, `test/system/{market_shop,market_orders}_test.rb`; supports `test/support/{market,market_listings,market_auctions,steam_sign_in}.rb` (`open_market!(archive_price_rare: 500, first_opened_at: …)`, `listing!(seller:, card_season:, current_price:)`, `fund!`), stock via `Game::Market::ArchiveStock.create!`, deposits via `Game::Market::ArchiveDeposit.create!(player_id:, card_season_id:, quantity:, updated_at:)`. Fixtures: `catalog_card_seasons(:common_card_one|:uncommon_card_one|:rare_card_one)` ("Tin Soldier", "Blue Depths" slug `blue-depths`). Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/market/archive_offers.rb` -- expose the offer scope and price, add `entrusted_day_sql`, `featured`, `for_card`.
- [x] `app/domains/game/app/queries/game/market/market_grid.rb` -- per Code Map.
- [x] `app/domains/game/app/queries/game/market/listing_filters.rb` -- `searched_card(locale)`.
- [x] `app/controllers/markets_controller.rb` -- settings, buyable, grid, panel, counts, searched game.
- [x] `app/views/markets/{screen.html.erb,screen.turbo_stream.erb,_tiles.html.erb,_empty.html.erb,_shop_panel.html.erb}` -- per Code Map and matrix.
- [x] `app/views/market/shops/_offer.html.erb` -- `size:` and `tile_id:` locals.
- [x] `app/components/button_component.{rb,html.erb}` -- `data:` option on links.
- [x] `app/controllers/market/orders_controller.rb`, `app/views/market/orders/{new,_available}.html.erb` -- Archives lines and the dialog.
- [x] `app/frontend/styles/market-shop.css` -- panel and order-form lines.
- [x] `config/locales/en.yml`, `fr.yml` -- every new string.
- [x] `test/domains/game/market/market_grid_test.rb` -- every sort's mixed order (price asc/desc with ties, ending, newest by day), paging `more`, filters incl. price bounds and `hide_mine`, unpriced rarity absent, nil settings falls back to listings; `offers_count`.
- [x] `test/domains/game/market/archive_offers_test.rb` -- `featured` order and limit, `for_card`.
- [x] `test/domains/game/market/listing_filters_test.rb` -- `searched_card` one game / several / none.
- [x] `test/controllers/market_shop_panel_test.rb` (new) -- panel count, tiles, wanted first, link; empty at 0 without link; visitor tiles to the card detail; grid mixes an offer; search note with both counts; one-game lines with PASSER UN ORDRE (enabled, disabled for a visitor); no DOM id collision with the shop's `archive-offer-*`; no database ids.
- [x] `test/controllers/market/orders_controller_test.rb` -- Archives lines and the ACHETER link when no listing; none with a listing; disabled when suspended.
- [x] `test/system/market_archive_offers_test.rb` (new, written not run) -- the Verify flow.

**Acceptance Criteria:**
- Given Rare priced at 500 with Blue Depths in stock and two listings at 80 and 900, when a signed-in player opens ANNONCES sorted by ascending price, then the Shop panel shows Blue Depths with "Voir toute la boutique ▸", and the grid reads 80, Blue Depths at 500 "prix fixe", 900.
- Given that player searches for Blue Depths, which only the Archives hold, then the grid shows its offer under "Aucune annonce de joueur pour Profondeurs bleues." with PASSER UN ORDRE; following it, the order form shows the Archives line "ACHETER · 500", which opens the purchase confirmation.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session read the diff, made three fixes and reran the checks.
- `OpenListings.build` is public so `MarketGrid` builds listing rows the same way; `ArchiveOffers.offers` bounds the fixed price itself and ignores `hide_mine`, so the shop and the grid share it.
- `MarketGrid` sorts on the union's own columns; `ArchiveOffers.featured` orders by entrusting day, then card-season (the day, not the time, as the grid).
- The order form's ACHETER is active while `@settings.open` (not merely "not suspended"), and is a secondary button: PASSER L'ORDRE stays the screen's one primary.
- The one-game lines show only when the search is the sole filter: with a rarity or price filter, "nothing for sale" is not established, so the usual empty lines stay.
- The panel keeps the Brotherhood's line when empty (one shape); English heading "THE BROTHERHOOD'S SHOP", as the shop's own name.
- The search note now reads "n annonces" (was the bare number); `markets_controller_test.rb` was adjusted.

## Plan Change Log

## Review Triage Log

## Design Notes

- One SQL union keeps "Charger plus" correct under every sort; merging two pages in Ruby would skip or repeat rows across pages.
- Market tiles carry no DOM id: the purchase stream replaces or removes `archive-offer-<slug>-<n>` on the shop screen, and the panel and the grid may hold the same edition. After a purchase from the market, the tile stays until the next load (the market refreshes on arrival).
- Offers in the "ending" sort follow the listings by ascending price, the shop's default.
- The panel count is distinct cards, as the shop's own count.

## Verification

**Commands:** (with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_k PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/market/market_grid_test.rb test/domains/game/market/archive_offers_test.rb test/domains/game/market/listing_filters_test.rb test/domains/game/market/open_listings_test.rb test/controllers/market_shop_panel_test.rb test/controllers/markets_controller_test.rb test/controllers/market_filters_test.rb test/controllers/market_wanted_panel_test.rb test/controllers/market test/components` -- expected: green
- `npm run format:check`, `npm run lint:css` -- expected: pass (`npm run test:js` if TypeScript is touched)
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched Ruby files, `bundle exec i18n-tasks missing` -- expected: pass
- Do not run system tests or the full suite; write the system test only.

## Auto Run Result

- **Summary:** ANNONCES shows the Shop panel above the listings (distinct-card count, the Brotherhood's line, four featured Archive offer tiles at card-s with the viewer's wanted cards first then the latest entrusted, three on the phone, "Voir toute la boutique ▸" outside the frame; count 0 and the empty line without the link). `Game::Market::MarketGrid` mixes open listings and priced Archive stock in one `UNION ALL` under every sort and page (price sorts by fixed price, "se termine bientôt" after the listings, "les plus récentes" by the entrusting day); a search counts both ("n annonces · n cartes des Archives"). A search naming one game shows "Aucune annonce pour <card>." or, with only offers, "Aucune annonce de joueur pour <card>." with PASSER UN ORDRE (disabled for a visitor or a suspended market). The order form lists the Archives' editions when the game has no open listing, each ACHETER · <amount> opening the purchase confirmation dialog.
- **Files:** queries `market_grid.rb` (new), `archive_offers.rb` (`featured`, `for_card`, entrusting day, public scope and price), `listing_filters.rb` (`searched_card`), `open_listings.rb` (`build` public); controllers `markets_controller.rb`, `market/orders_controller.rb`; views `markets/{screen,screen.turbo_stream,_tiles,_empty}`, `markets/_shop_panel` and `markets/_order_prompt` (new), `market/shops/_offer` (`size:`, `tile_id:`), `market/orders/{new,_available}`; `button_component.rb` (`data:`); `market_helper.rb` (`market_found_note`); `market-shop.css`; `en.yml`, `fr.yml`; tests `market_grid_test.rb`, `market_shop_panel_test.rb`, `test/system/market_archive_offers_test.rb` (new), additions to `archive_offers_test.rb`, `listing_filters_test.rb`, `market/orders_controller_test.rb`, `markets_controller_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** the plan's targeted tests plus `test/helpers`: 606 runs, 0 failures (`gameble_test_k`, `PARALLEL_WORKERS=4`), then the panel test again after the last fixes, 11 runs green; `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, rubocop on touched Ruby files, `i18n-tasks missing` pass. No TypeScript touched. System test written, not run. No migration.
- **Residual risks:** nothing seen in a browser (panel frame, the hidden fourth tile under 720px, tags at card-s); after a purchase from the market the tile stays until the next load (market tiles carry no DOM id, so the shop's stream leaves them); the panel and the grid may show the same edition (the UX review's open question, kept as EXPERIENCE.md has it); the implementer saw `Market::SalesControllerTest` line 586 fail at random on a fresh database, also on the baseline; copy awaits the author's approval with the rest of the market-volume copy.
