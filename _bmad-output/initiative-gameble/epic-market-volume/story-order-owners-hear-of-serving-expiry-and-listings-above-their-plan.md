---
title: 'Order owners hear of serving, expiry and listings above their price'
type: 'feature'
ticket: '12'
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

**Problem:** A buy order's owner hears nothing when it is served, when it expires or when a holder lists the game above its price, and the bell shows one line per listed wanted card instead of one grouped line (epic R10, R6's listed-above line).

**Approach:** `game_market_notices` gains `order_id` and three kinds (`order_served`, `order_expired`, `listed_above_order`) behind three partial unique indexes; the notice handlers write and delete them; the bell shows the order lines and one grouped wanted line whose seen state is a `wanted:grouped` bell read; MES ORDRES shows the listed-above line under a running row; push and live reload follow.

## Boundaries & Constraints

**Always:**
- Migrations (timestamps from `20261123190000`, expand/contract): (1) `order_id` reference to `game_market_orders`, FK `validate: false`, no index; `listing_id` nullable; check `listing_id IS NOT NULL OR order_id IS NOT NULL` NOT VALID; the kind check swapped to add `order_served|order_expired|listed_above_order`, NOT VALID (as `20261114170000` did). (2) Validate the FK and both checks. (3) Concurrently: unique `(player_id, listing_id) WHERE order_id IS NULL`, then drop `index_game_market_notices_on_player_and_listing` concurrently. (4) Concurrently: unique `(player_id, order_id) WHERE kind = 'listed_above_order'`. (5) Concurrently: unique `(player_id, order_id) WHERE kind IN ('order_served','order_expired')`. Then regenerate `db/schema.rb`.
- `Notice` declares `listing` and `order` optional; `Notice.record(player_id:, kind:, listing_id: nil, order_id: nil, ...)` upserts with `unique_by:` the index name its row needs (no order → listing index; `listed_above_order` → listed-above index; else the order-end index), never columns; it still skips a removed player.
- Listing side (`WantedNotices`, heard on `CardListed` and on each of `WantedChoicesApplied`'s `listing_ids`): for each player `WantingPlayers` returns (seller excluded), if that player has an open order on the listing's game that reaches the edition's rarity (`Order.reaching`) and the listing's starting price is above the order's price, write `listed_above_order` (listing, order, other player = seller, amount = starting price), replacing that order's previous one; else the `wanted` notice as today.
- The listing's end (`AuctionSold`, `AuctionUnsold`, `ListingWithdrawn`, `ListingCancelled`) deletes the `listed_above_order` notices pointing at it. An order's end (`OrderServed`, `OrderExpired`, `OrderCancelled`, `OrderWithdrawn`, and each sale of `WantedChoicesApplied`) deletes its owner's `listed_above_order` notice for it; served then writes `order_served` (amount = price), expired writes `order_expired` (amount = price released).
- Bell, in the market slot, in this order: listing notices (as today, without `wanted` and order rows, at most five), then order lines (at most five, newest first), then the grouped wanted line. Order lines, action "Voir": served → card detail of the edition received; expired → MES ORDRES; listed above → that Annonce. Keys `order:<order token>:<noticed_at iso8601(6)>`.
- Grouped line: computed on load from the player's `wanted` notices on open listings, counting distinct cards that are still among the player's wanted rows, a card with a `listed_above_order` notice excluded; absent at zero; unseen when one of those listings was created after the `read_at` of the player's `game_bell_reads` key `wanted:grouped` (or none exists); opens `market_path(wanted: "1")`.
- `MarkBellRead` writes any key `wanted:grouped` or `wanted:grouped:<suffix>` as the key `wanted:grouped`, and never prunes it.
- `MarketPushNotice::EVENTS` gains `OrderServed`, `OrderExpired` and `WantedChoicesApplied` (its sales, to each buyer); `WantedCardNotice::EVENTS` gains `WantedChoicesApplied` (its listings). `PlayerStream` sends the `market` topic for the order notices' events, and stays subscribed after every notice handler.
- MES ORDRES: under an EN COURS row with a `listed_above_order` notice, the line "<name> vend <card> à <amount>, au-dessus de votre ordre." and a link-variant `ButtonComponent` "VOIR L'ANNONCE ▸" to that Annonce, clickable above the row's stretched title link.
- Every string in `en.yml` and `fr.yml`; French plural keys with `zero`; no database id in a key, URL or DOM.

**Never:**
- No daily limit on the grouped line's return (left open by the UX review; out of the epic's scope by its Boundaries).
- No seller name in the bell's listed-above line; no push for `listed_above_order`; no new count badge.
- No write of a notice outside `Notice.record` and the handlers' deletes; no publish from a handler.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Listed above | B has an open order at 100 reaching Rare; S lists a Rare at 150 | B: one `listed_above_order` (listing, order, S, 150); no `wanted` for B | No error expected |
| Listed below | Same order; S lists at 90 | B: a `wanted` notice | No error expected |
| Order not reaching | B's order at 100 reaches Common only; S lists an Epic at 500, B's goal misses it | B: a `wanted` notice | No error expected |
| Second listing | S2 lists at 200 after S's 150 | Still one `listed_above_order` for the order, now the second listing | No error expected |
| Listing ends | S cancels (or the auction ends) | The `listed_above_order` pointing at it is gone | No error expected |
| Served | The order is served (direct sale or Confier table) | Its `listed_above_order` gone; one `order_served` | No error expected |
| Expired | `ExpireOrder` | Its `listed_above_order` gone; one `order_expired` with the price | No error expected |
| Cancelled / withdrawn | `CancelOrder` / `OrderWithdrawn` | Its `listed_above_order` gone; no new notice | No error expected |
| Removed player | The owner is banned or deleted | No notice written | Skipped by `Notice.record` |
| Grouped | Wanted notices on two open listings of two cards, one listing of each | One line, "2 cartes que vous cherchez sont en vente", unseen | No error expected |
| Grouped seen | The player reads the bell; no new listing | The line stays, read | No error expected |
| Grouped returns | A wanted card is listed after the read | The line is unseen again | No error expected |

</intent-contract>

## Code Map

- Every path is relative to `/home/teyermann/projets/gameble-mv-j`, a git worktree: work only there (never in any other `/home/teyermann/projets/gameble*` directory), start every shell command with `cd /home/teyermann/projets/gameble-mv-j &&`, call git as `/usr/bin/git`, never commit or push; run only the targeted non-system tests with the test `DATABASE_URL` of Verification, never the full suite or system tests. Postgres listens on 5433.
- `db/migrate/20261110150000_create_game_market_notices.rb`, `20261114170000_add_wanted_to_game_market_notices.rb`, `20261114170001_validate_game_market_notices_wanted.rb`, `20261110150001_add_player_listing_index_to_game_market_notices.rb` -- the table, the check swap pattern, the concurrent index pattern.
- `app/domains/game/app/models/game/market/notice.rb` -- `record_for(event, **)`, `record`; `KINDS`.
- `app/domains/game/app/handlers/game/market/handlers/{wanted_notices,outbid_notices,outcome_notices,removal_notices}.rb` -- handler shape; `WantedNotices` is the listing side to extend. Add one handler (e.g. `order_notices.rb`) for the order ends and the listing ends.
- `config/initializers/event_store.rb` -- subscribe the new handler and widen `WantedNotices` to `WantedChoicesApplied`, next to the other notice handlers, before `PlayerStream` (line ~54).
- Events: `OrderServed.about` data `order_id, buyer_id, seller_id, card_season_id, price`; `OrderExpired/Cancelled/Withdrawn.about` data `order_id, player_id, card_id, amount`; `WantedChoicesApplied` data `seller_id, sales: [{order_id, buyer_id, card_season_id, price}], listing_ids, entrusted`; `CardListed` `listing_id, seller_id, card_season_id`; listing ends carry `listing_id` (`listing_ending.rb`, `cancel_listing.rb`, `auction_settlement.rb`).
- `app/domains/game/app/models/game/market/{order,listing}.rb` -- `Order.open_at(now)`, `Order.reaching(rarity_name)` (joins settings); `Listing.open_now`, `starting_price`, `created_at`, `card_season_id`, `seller_id`, `token`. `Catalog::CardSeason` `card_id`, `rarity` (enum name).
- `app/domains/game/app/queries/game/market/wanting_players.rb`, `wanted_card_ids.rb` (the viewer's wanted card ids), `wanted_notice_players.rb` (`call` feeds PlayerStream: make it read `wanted` and `listed_above_order`; `first_in` feeds the wanted push: keep `wanted` only), `market_notices.rb` (`call` must leave out `wanted` and rows with an order; `of_kinds` unchanged), `card_names.rb`, `player_orders.rb` (Row gains the listed-above line for open orders), `Catalog::LatestPublishedCardSeasons`, `Catalog::CardViews` (`id` is the slug used by `card_path(slug:)`).
- `app/domains/game/app/queries/game/bell_items.rb` -- `Result` gains the order lines and the grouped line; `PER_KIND`.
- `app/domains/game/app/models/game/bell_read.rb`, `operations/game/mark_bell_read.rb` (`write`, `forget_oldest`, `KEY_FORMAT`), `queries/game/bell_read_keys.rb`.
- `app/helpers/bell_helper.rb` -- `bell_lines`, `bell_market_line`, `MARKET_TARGETS` (drop `wanted`), `BellLine` (add `read:` default false); `app/views/bells/_line.html.erb` -- `bell_read` becomes `!line.lasting && (line.read || read_keys.include?(line.key))`. The grouped line's DOM key is `wanted:grouped:<newest listing created_at iso8601(6)>`, so the browser's per-page read set (`app/frontend/controllers/bell_controller.ts` `readHere`) does not hide a returning line; no TypeScript change needed.
- `app/models/player_stream.rb` -- `BALANCE_EVENTS`, `MARKET_EVENTS`, `notices` branches (`OrderServed`, `WantedChoicesApplied`, and the `when *BALANCE_EVENTS` fallthrough that the order end events hit today), `market_notices`.
- `app/models/market_push_notice.rb`, `app/jobs/market_push_notice_job.rb` -- notices are `{player_id:, listing_id:}` read back through `MarketNotices.of_kinds`; order notices need `{player_id:, order_id:}` and a read of order notices by order ids; paths: served → `card_season_path`, expired → `market_my_orders_path`. `app/models/wanted_card_notice.rb` -- `call` takes the event's listing ids.
- `app/views/market/my_orders/_group.html.erb`, `app/helpers/market_orders_helper.rb` `order_row_note`, `app/components/market_row_component.html.erb` (note slot), `app/frontend/styles/market-rows.css` (`.market-row__title::after` stretches the title: give the note's link `position: relative` and a z-index above it). `app/views/market/orders/_available.html.erb` shows the link-variant "VOIR L'ANNONCE" pattern.
- Locales: `shell.bell.market.*_html` (keys built from the kind, ignored by i18n-tasks unused), `push_notices.market_*`, `market.my_orders.*`. Remove `shell.bell.market.wanted_html` in both.
- Tests to update or mirror: `test/domains/game/market/{wanted_notices,market_notices,outbid_notices,removal_notices}_test.rb`, `test/domains/game/mark_bell_read_test.rb`, `test/helpers/bell_helper_test.rb`, `test/models/player_stream_test.rb`, `test/jobs/market_push_notice_job_test.rb`, `test/jobs/wanted_card_notice_job_test.rb`, `test/controllers/bells_controller_test.rb`, `test/controllers/market/my_orders_controller_test.rb`, `test/system/market_orders_test.rb`, `test/system/market_outbid_test.rb` (bell pattern). Supports `test/support/{market,market_orders,market_listings,market_sales,market_auctions}.rb`. Wanted rows come from `Game::Market::RefreshWantedJob` after commit: tests reading wanted rows after an event perform those jobs first (`include ActiveJob::TestHelper`). Never name a model in a test class body.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261123190000..20261123190004_*.rb`, `db/schema.rb` -- the five migrations of Always; schema regenerated from the migrations.
- [ ] `app/domains/game/app/models/game/market/notice.rb` -- kinds, optional associations, index names, `record` choosing its index.
- [ ] `app/domains/game/app/handlers/game/market/handlers/wanted_notices.rb` -- listed-above or wanted per wanting player; `CardListed` and `WantedChoicesApplied` listings.
- [ ] `app/domains/game/app/handlers/game/market/handlers/order_notices.rb` (new) -- order ends and listing ends per Always.
- [ ] `config/initializers/event_store.rb` -- subscriptions, before `PlayerStream`.
- [ ] `app/domains/game/app/queries/game/market/` -- `market_notices.rb` filter; an order-notices query (bell lines, push lines by order ids, the listed-above line per open order); a grouped-wanted query (count, the one card's title, newest listing time, seen); `wanted_notice_players.rb` `call`; `player_orders.rb` row field.
- [ ] `app/domains/game/app/queries/game/bell_items.rb`, `app/helpers/bell_helper.rb`, `app/views/bells/_line.html.erb` -- order lines and the grouped line.
- [ ] `app/domains/game/app/operations/game/mark_bell_read.rb` -- `wanted:grouped` key folding and never pruned.
- [ ] `app/models/player_stream.rb`, `app/models/market_push_notice.rb`, `app/jobs/market_push_notice_job.rb`, `app/models/wanted_card_notice.rb` -- reloads and pushes.
- [ ] `app/views/market/my_orders/_group.html.erb`, `app/helpers/market_orders_helper.rb`, `app/frontend/styles/market-rows.css` -- the listed-above line and its link.
- [ ] `config/locales/fr.yml`, `en.yml` -- bell: `order_served_html` "Votre ordre sur %{card} est servi : la carte rejoint votre collection." / "Your order on %{card} was filled: the card joins your collection."; `order_expired_html` "Votre ordre sur %{card} a expiré. Vos %{amount} sont de nouveau disponibles." / "Your order on %{card} expired. Your %{amount} are available again."; `listed_above_order_html` "%{card} est en vente à %{amount}, au-dessus de votre ordre." / "%{card} is on sale for %{amount}, above your order."; grouped (zero/one/other) one "%{card}, une carte que vous voulez, est en vente." / "%{card}, a card you want, is on sale.", other "%{count} cartes que vous cherchez sont en vente." / "%{count} cards you are looking for are on sale.", fr zero "Aucune carte que vous cherchez n'est en vente." / en zero "No card you are looking for is on sale."; push titles "Ordre servi" / "Order filled", "Ordre expiré" / "Order expired", bodies as the bell sentences in plain text; MES ORDRES "%{name} vend %{card} à %{amount}, au-dessus de votre ordre." / "%{name} is selling %{card} for %{amount}, above your order." and "VOIR L'ANNONCE ▸" / "SEE THE LISTING ▸"; drop `wanted_html`.
- [ ] Tests -- every matrix row; handler tests (listed above vs below, replacement, cancellation deletes, served writes `order_served` and deletes, expired, cancelled, `WantedChoicesApplied` sales and listings, removed player, each upsert names its index — assert the `unique_by` passed is an index name, e.g. by checking `Notice.record`'s choice or the SQL's `ON CONFLICT ... WHERE`); query tests for the grouped line (count of distinct cards, listed-above card excluded, ended listing excluded, seen/unseen by `wanted:grouped` read_at); `mark_bell_read_test` (folding, never pruned); bell helper, player stream, push job, my_orders controller updates; one system test in `test/system/market_orders_test.rb`: a player with an order sees the listed-above line in MES ORDRES and the bell, then the served line after a direct sale; the grouped wanted line counts two cards and turns seen once the bell is read.

**Acceptance Criteria:**
- Given B's open order and S's listing of that game above its price, when B opens MES ORDRES, then the row shows "<S> vend <card> à <amount>, au-dessus de votre ordre." with VOIR L'ANNONCE ▸ to the Annonce, and B's bell shows "<card> est en vente à <amount>, au-dessus de votre ordre."
- Given that order is then served by a direct sale, when B opens the bell, then the served line shows and the listed-above line is gone.
- Given wanted notices on two open listings of two different cards, when the player opens the bell, then one line reads "2 cartes que vous cherchez sont en vente." and counts as unseen; after "Tout marquer comme lu" and a reload, it is read.

## Implementation Notes

- Built by one implementing subagent from this plan; the orchestrating session read the diff and reran the checks.
- `order_id` is added with `add_column` + `add_foreign_key validate: false` (same result as `add_reference` with no index); the partial listing index and the old index's removal share one concurrent migration.
- Fix after hand-back: `MarketPushNotice::ORDER_KINDS` named `Game::Market::Notice` at load, which loaded `ApplicationRecord` from the event store's `to_prepare` and broke `ReadOnlyRequestsTest` (GETs no longer write-prevented); it is now a literal list.
- New queries: `OrderNoticeLines` (bell lines, push lines by order ids), `GroupedWanted` (the grouped line); `PlayerOrders::Row#listed_above` feeds MES ORDRES. `BellRead::GROUPED_WANTED_KEY` holds `wanted:grouped`.
- The grouped line has `path: nil`, so only a click or "Tout marquer comme lu" marks it read, not a visit to the market.
- French copy uses U+202F before ":" as the rest of `fr.yml`. `i18n-tasks unused` lists the new `push_notices.market_order_*` keys, like the existing dynamic `push_notices.market_*` ones.
## Plan Change Log

## Review Triage Log

## Design Notes

- The ticket's `unknown` (at most once per card per day) is not built: the epic's Boundaries put the UX review's left-open questions out of this epic, and EXPERIENCE.md's accepted return rule (a listing created after the read, still open on load) is what the ticket describes.
- The grouped line's DOM key carries the newest listing's time only so the browser's per-page read set lets a returning line show; the server stores one key, `wanted:grouped`, whose `read_at` (`GREATEST` on upsert) is the seen time.
- The grouped count also requires the card to be among the player's wanted rows, so a card bought or no longer missing stops counting (EXPERIENCE.md: it counts the cards the VOULUE tag marks).
- Listing ends do not reload the order owners' bells (their notice is deleted before `PlayerStream` runs); the line goes on the next load.

## Verification

**Commands:**
- `cd /home/teyermann/projets/gameble-mv-j && RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_schema_j SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- expected: only the notices table changes in the diff
- `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_j PARALLEL_WORKERS=4; RAILS_ENV=test bin/rails db:drop db:create db:schema:load; bin/rails test <the touched and new non-system test files>` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks missing`, `bundle exec rubocop` on touched Ruby files -- expected: pass
- Do not run system tests or the full suite.

## Auto Run Result

- **Summary:** `game_market_notices` carries an order (`order_id`, nullable `listing_id`, an at-least-one check, three new kinds, the player/listing unique index now partial beside two player/order partial indexes); `Notice.record` upserts against the index name its row needs. A listing (`CardListed`, or `WantedChoicesApplied`'s listings) writes `listed_above_order` for a wanting player whose open order reaches the edition below the starting price, replacing the order's previous one, else `wanted`; the listing's end deletes it; an order's end deletes it, and served/expired write `order_served`/`order_expired`. The bell shows the order lines and one grouped wanted line (distinct still-wanted cards on open listings, seen by the `wanted:grouped` bell read that `MarkBellRead` folds and never prunes); MES ORDRES shows the listed-above line with VOIR L'ANNONCE ▸; push and the bell's live reload cover the order events and the Confier table.
- **Files:** migrations `20261123190000`..`20261123190004`, `db/schema.rb`; `notice.rb`, `bell_read.rb`; handlers `wanted_notices.rb`, `order_notices.rb` (new); queries `market_notices.rb`, `order_notice_lines.rb` (new), `grouped_wanted.rb` (new), `wanted_notice_players.rb`, `player_orders.rb`, `bell_items.rb`; `mark_bell_read.rb`; `bell_helper.rb`, `bells/_line.html.erb`; `market_orders_helper.rb`, `market-rows.css`; `player_stream.rb`, `market_push_notice.rb`, `market_push_notice_job.rb`, `wanted_card_notice.rb`; `event_store.rb`; `en.yml`, `fr.yml`; tests `order_notices_test`, `grouped_wanted_test`, `order_notice_lines_test` (new) and updates to market notices, mark bell read, bell helper, bells and my orders controllers, player stream, push notice model and jobs, `test/system/market_orders_test.rb` (two new system tests).
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** schema regenerated from the migrations on PG18 (only the notices table changes); `test/domains/game/market`, `mark_bell_read`, `bells_controller`, `test/controllers/market`, `bell_helper`, `test/jobs`, `market_push_notice`, `player_stream`, `read_only_requests`, `accounts_controller`: 1329 runs, 0 failures (`gameble_test_j`, 4 workers); `zeitwerk:check`, `packwerk check`, `check_planning_references`, `check_file_sizes`, `format:check`, `lint:css`, `i18n-tasks missing`, rubocop pass. System tests written, not run.
- **Residual risks:** the two system tests are unrun; `OrderWithdrawn` has no publisher yet (its handling is tested by calling the handler); listing ends do not reload the order owners' bells live; deleting `listed_above_order` notices by listing has no listing index (the partial listed-above index is small); the ticket's `unknown` (once per card per day) is not built, out of the epic's scope; English copy is a draft for the author.

