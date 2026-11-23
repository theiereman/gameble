---
title: 'Sellers see which of their copies other players want'
type: 'feature'
ticket: '13'
created: '2026-11-23'
status: 'built'
baseline_revision: '6a3d65a734bc1a388ed551ce8667599d4dc37448'
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

**Problem:** The wanted table (`game_market_wanted`, `WantedCounts`) exists, but a seller sees nowhere that other players want their copies: no Vos cartes voulues panel, no DEMANDÉE badge, no VOULUES PAR D'AUTRES chip, no card-detail line.

**Approach:** One seller-side query, `Game::Market::WantedCopies`, lists the viewer's free copies (quantity > reserved, rarity set) that `WantedCounts` counts at their card and rarity (viewer excepted), one per edition, with the seeker count and `EligibleOrders.best`'s order, most sought first. The market's four chips render the panel above the chip row (signed-in only); Mettre en vente's cells carry the badge and its filter row the chip; the card detail shows the line above CONFIER / METTRE EN VENTE.

## Boundaries & Constraints

**Always:** reads only (no write, no event); counts come from `WantedCounts`, orders from `EligibleOrders`, never a second reach or wanted formula; a count never names a player; the viewer's own goals and orders never count; tokens/refs only in HTML and URLs (ref = `slug:season`, no ids); every string in `en.yml` and `fr.yml` (French as the Copy deck draws it, English beside it; French plurals with `zero`; U+202F before `:` `;` `?`); no planning ids; files ≤ 400 lines (Ruby/TS), ≤ 500 (CSS); no `style` attributes; server-rendered markup; "Tout voir" is `ButtonComponent variant: :link`; frontend passes `npm run format:check` and `npm run lint:css`.

**Never:** the Confier grid's DEMANDÉE badge, its recap or the wanted table (entry 14); the buyer's VOULUE tag/chip (done); the collection grid; live refresh of the panel (read on load); a migration; changing `WantedCounts`, `EligibleOrders` or `RefreshWanted`.

**Decision on the ticket's `unknown`:** EXPERIENCE.md (Market screen row, author-accepted 2026-11-20) places the panel "on every chip"; the ticket description says the same. Build it on every chip; the validation report lists only-ANNONCES-and-MES-VENTES as a low open question for the author's review.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Goal and order seekers | viewer holds 1 free Rare; B's goal misses the card; C's order reaches Rare | one copy, seekers 2, order = C's | none |
| Same player both ways | B wants by goal and order | seekers 1 | none |
| Viewer's own | viewer's goal / order on a card they hold | not counted (absent if no one else) | none |
| Order not reaching | C's order reaches common only; viewer holds Rare | seekers from goals only; order nil | none |
| Only copy / reserved | quantity 1, reserved 0 → listed; quantity 1, reserved 1 → absent | as stated | none |
| Order of tiles | several wanted editions | seekers desc, then best order price desc, then ref | none |
| None wanted | signed-in, nothing wanted | panel with count 0 and the empty line, no "Tout voir" | none |
| Visitor | no player | no panel; `WantedCopies.call(nil)` → [] | none |
| Banned seeker | banned player's goal row | not counted (`Wanted.in_play`) | none |
| Wanted chip on | Mettre en vente `filter[wanted]=1` | grid keeps only wanted editions; status line "<n> cartes voulues par d'autres joueurs" | none |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/market/wanted_counts.rb` -- `WantedCounts.call(card_ids, except:)` → `{ [card_id, "rare"] => n }`, default 0. Reuse as is.
- `.../eligible_orders.rb` -- `EligibleOrders.best(card_season_ids, except:, now:)` → `{ card_season_id => Order }`. Reuse as is.
- `.../entrustable_copies.rb` -- `EntrustableCopies.ref(slug, season_number)`, `.resolve(refs)`; `.../sellable_copies.rb` -- the Mettre en vente grid query (`call(..., refs:)` exists; `count` lacks `refs:`), FROM joins to mirror for holdings → card-seasons → cards/seasons. `Game::Holding` has no associations (string joins). `Catalog::Rarity::TIERS` `{1=>:common..5=>:legendary}`; `Catalog::CardViews.call(card_season_ids, locale:)` → views for `CardComponent`.
- `app/domains/game/app/models/game/market/copy_filter.rb` -- `Data.define(:query, :rarities, :doubles, :triples)` with a custom `initialize`; `conditions`/`binds`/`count`/`narrowing?`/`to_params`. Shared with Confier.
- `app/controllers/concerns/market/copy_grid.rb` -- `copy_filter(doubles_by_default:)` parses `params[:filter]`; `copy_pages` carries `filter.to_params`.
- `app/controllers/market/sales_controller.rb` -- `load_page`/`load_grid` (`@copies`, `@prices`, `@orders`), `choose(ref)`, `prefill` (chooses `params[:ref]`; a panel tile links `new_market_card_sale_path(slug:, ref:)`).
- Views `app/views/market/sales/{_cell,_grid}.html.erb`, `new.turbo_stream.erb` (appends cells: they must keep the badge), `app/views/market/{_copy_filters,_copy_filter_fields}.html.erb` (shared with Confier: the chip is opt-in by a local), `app/helpers/market_sales_helper.rb` `sale_cell_label` (accessible name of a cell, the badge's spoken text goes there).
- `app/frontend/controllers/copy_filters_controller.ts`, `app/frontend/lib/entrust.ts` (`EntrustFilter`, `filterCount`, `filtering`) -- add an optional `wanted` target/field; Confier has none.
- `app/controllers/concerns/market/desk_loading.rb` -- `load_desk`, called by `MarketsController#show` (html), `Market::MyBidsController`, `MySalesController`, `MyOrdersController`; `app/views/markets/_tab.html.erb` renders desk, suspended banner, mine, exchange preview, then `markets/chips` inside the `market-tab` frame: the panel goes right before the chips.
- `app/views/markets/_soon.html.erb` + `.market-soon*` in `app/frontend/styles/market-desk.css` -- a strip of linked card tiles to mirror (`CardComponent size: :s`, rarity colour classes). `PanelComponent(tag:, **html)`, `EmptyStateComponent.new(line:)`, `PicoinAmountComponent.new(amount:)`, `ButtonComponent.new(variant: :link, href:, aria_label:)`.
- `app/controllers/cards_controller.rb#show` (279 lines) -- `@entrustment = CardEntrustment.call(...)` (nil unless market open and the player holds the card); `app/views/cards/_detail.html.erb` `card-detail__market` block (line ~218), locals via `local_assigns.fetch`; `app/views/cards/show.html.erb` passes locals.
- Styles: new `app/frontend/styles/market-wanted.css` imported in `app/frontend/entrypoints/application.css` next to `market-sale-order.css`; tokens per DESIGN.md: badge `--color-on-accent` background, `inset 0 0 0 2px var(--color-accent)`, `--color-accent` text, `--font-label`, at a sale cell's top-right 8px in (the cell is `position: relative`; the chosen check sits at top -8px right -8px); panel tiles on `--color-panel-sunken`, 8px padding, name bold `--color-text-max`, seekers `--color-text` 11px bold, order in `--color-gold`, "▸" right, hover `--color-panel-raised`; four tiles in a row on desktop, three stacked rows (≥ 44px) on a phone (hide the fourth under 720px).
- Locales: fr `market.copy_filters` ~2428, `market.sales.new` ~2804, `markets.screen` ~2872, `card_details` ~4671 (`entrust`/`list` ~4708); en `card_details` ~1418, `market.copy_filters` ~3404, `market.sales` ~3770, `markets.screen` ~3839.
- Tests to mirror: `test/domains/game/market/wanted_counts_test.rb`, `wanted_refresh_test.rb` (`aim` via `Game::AddGoal`, `Game::Market::RebuildWanted.new.call(player:)`), `test/support/{holdings,market_orders,market,market_auctions,game_sets}.rb` (`hold`, `order!`, `fund!`, `open_market!`, `insert_set`), `test/controllers/market/sales_controller_test.rb`, `test/controllers/markets_controller_test.rb`, `test/controllers/market_wanted_cards_test.rb`, `test/controllers/cards_controller_test.rb`, `test/system/market_direct_sale_test.rb` (sign-in and sale flow). `order!` writes no wanted row: rebuild the buyer's rows after it.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/market/wanted_copies.rb` -- `WantedCopies.call(player, card_id: nil, now: Time.current)` → `[Copy(card_season_id, card_id, ref, rarity, seekers, order)]`, `[]` for nil: the player's free editions (quantity > reserved, rarity not null, optional card) whose card has any wanted row (prefilter `card_id IN (SELECT card_id FROM game_market_wanted)`), seekers from `WantedCounts` (except the player), kept when positive, order from `EligibleOrders.best` (except the player), sorted per the matrix.
- [x] `copy_filter.rb` -- add `wanted_ids` (nil by default): `wanted?`, counted in `count`, `AND catalog_card_seasons.id IN (:wanted_ids)` when set, `to_params` adds `wanted: "1"`; `sellable_copies.rb` needs nothing more once the filter carries it.
- [x] `copy_grid.rb` -- `copy_filter(doubles_by_default:, wanted_ids: nil)`: when `filter[wanted]` is present and a callable/array is given, set `wanted_ids`; Confier unchanged.
- [x] `sales_controller.rb` -- load `@wanted = WantedCopies.call(current_player).index_by(&:ref)` (signed in only) before the grid; pass its ids to `copy_filter`; keep `@wanted` for cells and the chip count.
- [x] `_copy_filters.html.erb` -- optional local `wanted: nil` (count): when given, a `filter-chip` checkbox `filter[wanted]` (target `wanted`) labelled "VOULUES PAR D'AUTRES · <n>", accessible name "Voulues par d'autres, <n> cartes"; `_copy_filter_fields.html.erb` carries `filter[wanted]`; `market/sales/new.html.erb` passes `wanted: @wanted.size` when signed in.
- [x] `_grid.html.erb` -- with the wanted filter on, the status line reads the wanted-count line instead of `copy_matches`.
- [x] `_cell.html.erb` + `market_sales_helper.rb` -- a wanted cell shows the aria-hidden badge "DEMANDÉE · <n>"; `sale_cell_label` gains `wanted:` and appends "demandée par <n> joueurs".
- [x] `copy_filters_controller.ts`, `lib/entrust.ts` -- optional `wanted` target counted in the active-filter count and cleared by `clear()`; vitest for `filterCount` with `wanted`.
- [x] `desk_loading.rb` -- `@wanted_copies = WantedCopies.call(current_player) if current_player`.
- [x] `app/views/markets/_wanted_panel.html.erb` (new) + `_tab.html.erb` -- rendered before the chips when `@wanted_copies` is set: `PanelComponent tag: :section` labelled by an h2 kicker "VOS CARTES VOULUES" with the count (editions) at the right; a list of the first four as tiles (one link each to `new_market_card_sale_path(slug:, ref:)`, `CardComponent size: :s`, name, seekers line, "Ordre <amount>" or "Aucun ordre", "▸", accessible name per the Copy deck), or `EmptyStateComponent` with the empty line; "Tout voir" (`variant: :link`, to `new_market_sale_path(filter: { wanted: "1" })`, accessible name "Tout voir, vos cartes voulues") under the panel at its right, only when the count is positive.
- [x] `cards_controller.rb`, `cards/show.html.erb`, `cards/_detail.html.erb` -- when `@entrustment&.free&.positive?`, `@wanted = WantedCopies.call(current_player, card_id:)`; when not empty, above the CONFIER/METTRE EN VENTE buttons: the badge "DEMANDÉE" and "<n> joueurs la veulent · meilleur ordre <amount>" (or "· aucun ordre d'achat"), n the first (most sought) copy's seekers, the amount the best price among the copies' orders.
- [x] `app/frontend/styles/market-wanted.css` (+ import) -- panel, tiles, badge, card-detail line per the Code Map.
- [x] `config/locales/fr.yml`, `en.yml` -- the Copy deck's Wanted cards strings: panel kicker, empty line, seekers (plural; fr one "1 joueur la veut"), "Ordre %{amount}", "Aucun ordre", tile label (with/without order), "Tout voir" and its label; badge "DEMANDÉE · %{count}" and "demandée par %{count} joueurs" (plural); chip label and spoken label; the wanted-count line (zero "Aucune carte voulue par d'autres joueurs", one "1 carte voulue par d'autres joueurs"); card detail "DEMANDÉE", "%{seekers} · meilleur ordre %{amount}", "%{seekers} · aucun ordre d'achat". English: "YOUR WANTED CARDS", "None of your cards is wanted right now.", "%{count} players want it", "Order", "No order", "See all", "SOUGHT · %{count}", "sought by %{count} players", "WANTED BY OTHERS · %{count}", "%{count} cards wanted by other players", "best order", "no buy order".
- [x] Tests -- `test/domains/game/market/wanted_copies_test.rb` (every matrix row of the query: counts, order, sort, own goals/orders, reserved, banned, nil); `copy_filter` wanted case where filter tests live (or in the new test); `sales_controller_test.rb` (badge and its spoken text on a wanted cell, chip count, `filter[wanted]=1` keeps only wanted cells and shows the line, page links carry it, no ids in HTML); `markets_controller_test.rb` or a new `test/controllers/market_wanted_panel_test.rb` (panel on ANNONCES and MES ORDRES with tile order, seekers, order amount and link with `ref`; count 0 and empty line; absent for a visitor); `cards_controller_test.rb` or a new file (the line with and without an order; absent when nobody wants it); `test/system/market_wanted_copies_test.rb` (the ticket's Verify flow).

**Acceptance Criteria:**
- Given a player whose free Rare is missing from B's goal and reached by C's order, when they open the market, then the Vos cartes voulues panel shows a tile reading "2 joueurs la veulent" and C's order; when they follow it, then Mettre en vente opens on that edition with the order banner, its cell reads "DEMANDÉE · 2", and the card detail shows "DEMANDÉE" and "2 joueurs la veulent · meilleur ordre <amount>".
- Given a visitor, when they open the market, then no Vos cartes voulues panel is drawn.
- Given a signed-in player with no wanted copy, when they open any market chip, then the panel shows the count 0 and "Aucune de vos cartes n'est voulue pour le moment.".

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session verified the diff and reran the checks.
- `WantedCopies` returns `Copy(card_season_id, card_id, ref, rarity, seekers, order)`; the panel's first four tiles get their `CardViews` in `DeskLoading`; tile accessible names come from the new `MarketWantedHelper#wanted_tile_label`; the card-detail line is its own partial `cards/_wanted_line`.
- On Mettre en vente filtered on one card, the VOULUES PAR D'AUTRES chip counts every wanted edition of the player, not only that card's; the grid itself keeps the card.
- A free copy means quantity > reserved: an edition held only inside a deck (sellable from the grid) is not listed as wanted.
- English copy chosen for the drafts: "SOUGHT · n" for DEMANDÉE, "WANTED BY OTHERS · n", "YOUR WANTED CARDS"; the author approves both languages.

## Plan Change Log

## Review Triage Log

## Design Notes

- Count and tiles are per edition (a card-season), as the mock's panel and the "VOULUES PAR D'AUTRES · 5" chip count the same five cells; the tile opens Mettre en vente on its card with its edition chosen (`ref`), so the banner shows that edition's best order.
- The card detail shows one line for the card: the most sought edition's count and the best order any held edition can serve. When two held editions are reached by different order owners, the count can be one below the union; accepted to keep `WantedCounts` the only counter.
- The wanted filter is carried as ids from `WantedCopies` rather than SQL in `CopyFilter`, so the grid, the chip and the badge read one source.

## Verification

**Commands:** (with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_b PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing)
- `bin/rails test test/domains/game/market/wanted_copies_test.rb test/controllers/market test/controllers/markets_controller_test.rb test/controllers/market_wanted_cards_test.rb test/controllers/cards_controller_test.rb` plus any new controller test file -- expected: green
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched Ruby files, `bundle exec i18n-tasks missing` -- expected: pass
- Do not run system tests or the full suite; write the system test only. Work only in `/home/teyermann/projets/gameble-mv-b`, starting every shell command with `cd /home/teyermann/projets/gameble-mv-b &&`; call git as `/usr/bin/git`; do not commit or stage.

## Auto Run Result

- **Summary:** `Game::Market::WantedCopies` lists a player's free copies other players want, one per edition, its seekers from `WantedCounts` (the player excepted) and its best order from `EligibleOrders.best`, most sought first, then best order, then ref. The market's four chips draw the Vos cartes voulues panel above the chip row for a signed-in player (count of wanted editions, up to four tiles linking to Mettre en vente on that edition, the empty line at 0, "Tout voir" to the grid filtered on wanted copies); Mettre en vente's cells carry "DEMANDÉE · n" and its spoken text, its filter row the VOULUES PAR D'AUTRES chip (`CopyFilter#wanted_ids`) with its status line; the card detail shows "DEMANDÉE" and the seekers line with the best order above CONFIER / METTRE EN VENTE.
- **Files:** query `wanted_copies.rb` (new); `copy_filter.rb` (`wanted_ids`); controllers `copy_grid.rb`, `desk_loading.rb`, `sales_controller.rb`, `cards_controller.rb`; helpers `market_sales_helper.rb` (spoken count), `market_wanted_helper.rb` (new, tile label); views `markets/_wanted_panel` (new), `markets/_tab`, `market/_copy_filters`, `market/_copy_filter_fields`, `market/sales/{_cell,_grid,new}`, `cards/_wanted_line` (new), `cards/_detail`, `cards/show`; frontend `copy_filters_controller.ts`, `lib/entrust.ts` (+ test), `styles/market-wanted.css` (new) and its import; `en.yml`, `fr.yml`; tests `wanted_copies_test.rb`, `market_wanted_panel_test.rb`, `card_wanted_line_test.rb` (new), additions to `sales_controller_test.rb`, system test `market_wanted_copies_test.rb` (new, not run).
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** `bin/rails test` on the new tests, `test/controllers/market`, markets, wanted cards, cards controller, sellable/entrustable copies and helpers: 487 runs, 0 failures (`gameble_test_b`, `PARALLEL_WORKERS=4`); `npm run test:js` 1546 passed; `format:check`, `lint:css`, `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `i18n-tasks missing`, rubocop on the 13 touched Ruby files pass. System test written, not run. No migration.
- **Residual risks:** the panel shows on every chip (the open low question of the UX review: only ANNONCES and MES VENTES?); the card-detail count is the most sought edition's, one below the union when two held editions are reached by different order owners; the chip count ignores the card filter of `/sell/cards/:slug`; the implementer saw `SalesControllerTest` "the chosen copy shows the best order's banner" fail twice in three runs before this change touched it (it asserts the order's id is absent from the HTML, which collides with small numeric attribute values); English and French drafts await the author's approval.

