---
title: 'A notable direct sale appears in the feed'
type: 'feature'
ticket: '10'
created: '2026-11-23'
status: 'built'
baseline_revision: '49a314d71e43bb9a9b6ab1da32c40a4fbd458d4e'
route: 'full'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A direct sale to a buy order, from Mettre en vente (`OrderServed`) or from the Confier wanted table (each sale of `WantedChoicesApplied`), leaves no trace in the activity feed, while the feed's rule (`market-economy.md`, Sales in the feed) says it follows the same rule as a listing's sale.

**Approach:** `game_feed_entries` gains `order_id`; a sale entry carries exactly one of listing and order, unique per order as per listing. `SaleFeed` hears `OrderServed` and `WantedChoicesApplied` and writes through the one `FeedEntry.record_sale` rule; the feed readers price an order's entry from the order and let it through as they do a listing's sale, and the live feed broadcasts it.

## Boundaries & Constraints

**Always:** Expand/contract with strong_migrations: (1) add `order_id bigint`, its foreign key to `game_market_orders` `validate: false`, and a new check `game_feed_entries_sale_reference_check` = `(kind = 'sale') = (listing_id IS NOT NULL OR order_id IS NOT NULL) AND (listing_id IS NULL OR order_id IS NULL)` `validate: false`; (2) its own migration, a concurrent unique index on `order_id` where `kind = 'sale'` named `index_game_feed_entries_one_sale_per_order`; (3) validate the foreign key and the new check, then drop the old `game_feed_entries_sale_check` (reversible, with its expression). The notable rule is `FeedEntry.notable_sale?` unchanged (Épique/Légendaire, or price ≥ current version's `feed_threshold_multiple` × the rarity's minimum), read from `CurrentSettings` when the sale settles. The entry's `player_id` is the buyer, its price read from `order.price` (the entry stores no amount). Handlers run in the sale's transaction and publish nothing; `WantedChoicesApplied`'s sales written in ascending buyer id, then order id. Regenerate `db/schema.rb` from the migrations. No planning ids in code; files ≤ 400 lines; comment only external constraints.

**Never:** No feed entry for `ArchivePurchased` (no feed handler hears it). No new rendering, copy or locale keys: the sale sentence, headline and VENTES filter already render any `kind = "sale"` item with a price. No change to visibility rules: a sale entry shows whatever the buyer's visibility, hidden when the buyer is banned or deleted (the ticket's open question is settled this way). No change to `ReleasePlayer` (it already deletes entries naming the player), `SellToOrder`, `ApplyWantedChoices` or the event classes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Épique direct sale | `OrderServed` of an Épique (`portal_one`) at any price ≥ its minimum | one `sale` entry: buyer as player, order_id, card_season_id, rarity 4, listing_id nil | none |
| Common under the threshold | `OrderServed` of a Common at 129 (min 13 × 10) | no entry | none |
| Common at the threshold | Common at 130 through `SellToOrder` | one entry, in the sale's transaction | none |
| Wanted table, two notable sales | `WantedChoicesApplied` with two notable sales (and one cheap) | exactly two entries, one per order; handling the event again leaves two | ON CONFLICT DO NOTHING (unique per order) |
| Both references | insert a `sale` row with a listing_id and a real order_id | refused | `ActiveRecord::StatementInvalid` (check) |
| Neither reference / order on another kind | `sale` with neither; a `pull`-like kind row carrying an order_id | refused | check violation |
| Unknown order | `sale` with an order_id naming no order | refused | foreign key violation |
| Visibility | private buyer; banned/deleted buyer | listed to every viewer by `FeedEntries`, `NewFeedEntries(order_ids:)`, `VisibleFeedEntry`; hidden when removed | none |
| Price | an order's entry read by `FeedEntries`/`NewFeedEntries` | `price` = the order's price, so `FeedItems` keeps it | none |

</intent-contract>

## Code Map

- `db/migrate/20261110160000_add_sale_to_game_feed_entries.rb`, `…160001_add_one_sale_per_listing_index…`, `…160002_validate_game_feed_entries_sale.rb` -- the three-migration pattern to mirror. New: `db/migrate/20261123150000_add_order_to_game_feed_entries.rb`, `20261123150001_add_one_sale_per_order_index_to_game_feed_entries.rb` (`disable_ddl_transaction!`, `algorithm: :concurrently`), `20261123150002_validate_game_feed_entries_order.rb` (`validate_foreign_key :game_feed_entries, :game_market_orders`, `validate_check_constraint`, `remove_check_constraint` of `"(kind = 'sale') = (listing_id IS NOT NULL)"` named `game_feed_entries_sale_check`).
- `app/domains/game/app/models/game/feed_entry.rb` `record_sale(listing_id:, buyer_id:, …)` -- make `listing_id:` and `order_id:` both keyword args defaulting to nil; the row carries both; `unique_by:` is `:index_game_feed_entries_one_sale_per_order` when `order_id`, else the listing one. Existing callers (`SaleFeed`, `test/support/market_feed.rb`, `sale_feed_test.rb`) keep working.
- `app/domains/game/app/handlers/game/handlers/sale_feed.rb` -- today reads `AuctionSold` data (`listing_id`, `winner_id`, `card_season_id`, `final_price`). Map each event to its sales: `OrderServed` data `order_id, buyer_id, card_season_id, price` (seller_id ignored); `WantedChoicesApplied` data `sales: [{order_id, buyer_id, card_season_id, price}]` (symbol keys, as `WantedRefresh` reads them). One `CurrentSettings.call` and one `at` (`event.metadata[:timestamp] || Time.current`) per event.
- `config/initializers/event_store.rb` line 42 -- extend the `to:` list: `[ Game::Market::AuctionSold, Game::Market::OrderServed, Game::Market::WantedChoicesApplied ]`.
- `app/domains/game/app/queries/game/feed_entries.rb` `priced(items)` -- today prices only `entry.listing_id` from `Market::Listing#final_price`; also price `entry.order_id` from `Market::Order#price` (skip a query when there are no ids). `visible`/`owner_shown?` already treat any `kind == "sale"` by `Visibility.sale_listed?`: no change.
- `app/domains/game/app/queries/game/new_feed_entries.rb` -- add `order_ids: []`, scope `FeedEntry.where(kind: "sale", order_id: order_ids)`; visibility already kind-based.
- `app/domains/game/app/queries/game/visible_feed_entry.rb` -- already kind-based; only a test.
- `app/models/live_stream.rb` -- `EVENTS` gains `Game::Market::OrderServed`, `Game::Market::WantedChoicesApplied`; `notices`: `OrderServed` → `[ { order_id: } ]`, `WantedChoicesApplied` → one `{ order_id: }` per sale (never a `card_season_id` key: `LiveFeedJob` reads that key as a repost). `app/jobs/live_feed_job.rb` passes `order_ids: notices.filter_map { it[:order_id] }`.
- `test/support/market.rb` `forget_market!` -- delete `Game::FeedEntry.where.not(order_id: nil)` before `Game::Market::Order` (the new foreign key).
- Tests to mirror/extend: `test/domains/game/market/sale_feed_test.rb` (record, `sell!`, visibility tests), `test/jobs/live_feed_sale_test.rb`, `test/system/market_feed_test.rb`; arrangement helpers `test/support/market_orders.rb` (`order!`), `market_auctions.rb` (`fund!`), `holdings.rb` (`hold`), and `Game::Market::SellToOrder.new.call(player:, card_season_id:, order_token:, settings_token:)` as in `test/domains/game/market/sell_to_order_test.rb`; `ApplyWantedChoices` arrangement as in `test/domains/game/market/apply_wanted_choices_test.rb`. Fixtures: `catalog_card_seasons(:portal_one)` is the Épique, `:common_card_one`, `:rare_card_one`, `:legendary_card_one`; starting minimums common 13, rare 78, epic 223; `open_market!(feed_threshold_multiple: 10)`.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261123150000…150002` -- the three migrations per Code Map -- expand, index, contract.
- [ ] `db/schema.rb` -- regenerate: `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_schema_e SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- never hand-edit.
- [ ] `app/domains/game/app/models/game/feed_entry.rb` -- `record_sale` with `order_id:` -- one rule for both sources.
- [ ] `app/domains/game/app/handlers/game/handlers/sale_feed.rb` + `config/initializers/event_store.rb` -- hear both new events -- the domain half.
- [ ] `app/domains/game/app/queries/game/feed_entries.rb`, `new_feed_entries.rb` -- order price and `order_ids:` -- readers.
- [ ] `app/models/live_stream.rb`, `app/jobs/live_feed_job.rb` -- broadcast an order's entry live like a listing's.
- [ ] `test/support/market.rb` -- `forget_market!` clears order entries first.
- [ ] `test/domains/game/market/sale_feed_test.rb` -- every matrix row: `SellToOrder` of an Épique makes one entry carrying its order; Common at 129 none, at 130 one; a `WantedChoicesApplied` (through `ApplyWantedChoices`, or `SaleFeed.call` with the event built by `WantedChoicesApplied.with` on real served orders) with two notable sales makes their two entries once (call the handler again: still two); both-references, neither, order on another kind and unknown order refused (insert inside `transaction(requires_new: true)`, use a real order so the check, not the foreign key, refuses); `FeedEntries` price an order's entry at the order's price; `NewFeedEntries(order_ids:)` and `VisibleFeedEntry` visibility for a private, then banned buyer. If the file nears 400 lines, put the order cases in `test/domains/game/market/order_sale_feed_test.rb`.
- [ ] `test/jobs/live_feed_sale_test.rb` -- `LiveStream.notices` of `OrderServed` and `WantedChoicesApplied`; `LiveFeedJob.perform_now([ { order_id: } ])` prepends the entry.
- [ ] `test/system/market_feed_test.rb` -- one test: a direct sale served through `SellToOrder` (Épique `portal_one`, or the Rare at 900) shows in the activity feed with the buyer's name and "Bought for <price>".

**Acceptance Criteria:**
- Given a holder sells an Épique to a buy order, when anyone opens the activity feed, then a sale line names the buyer and the order's price, under TOUT and VENTES.
- Given the three migrations run on an empty Postgres 18 database, when the schema is dumped, then it equals the committed `db/schema.rb`.

## Implementation Notes

- The order cases live in `test/domains/game/market/order_sale_feed_test.rb` (separate setup with orders and wallets); `sale_feed_test.rb` is unchanged and still green.
- `SaleFeed` maps each event to a list of `record_sale` keyword sets; the wanted table's sales are sorted by buyer id, then order id, before writing.
- `FeedEntries.priced` reads listing and order prices with one query each, skipped when no entry carries that reference.
- The system test in `test/system/market_feed_test.rb` was written but not run, as the plan asks.

## Plan Change Log

## Review Triage Log

## Design Notes

- The foreign key on `order_id` (the listing column has none): the architecture asks for it; orders are never deleted by the app (account deletion keeps them as market history), so only test cleanup meets it.
- One `record_sale` for both sources keeps the notable rule in one place; the unique index is picked by which reference the row carries.

## Verification

**Commands:** (with `export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_e PARALLEL_WORKERS=4`; create it with `RAILS_ENV=test bin/rails db:create db:schema:load` if missing, after the schema is regenerated)
- `bin/rails test test/domains/game/market/sale_feed_test.rb test/jobs/live_feed_sale_test.rb test/jobs/live_feed_job_test.rb test/domains/game/market/sell_to_order_test.rb test/domains/game/market/apply_wanted_choices_test.rb test/domains/game/feed_test.rb` -- green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes` -- pass
- Do not run the system tests or the full suite; do not commit; leave `package-lock.json` alone; call git as `/usr/bin/git`.

## Auto Run Result

- **Summary:** a direct sale to a buy order, from Mettre en vente (`OrderServed`) or from the Confier wanted table (each sale of `WantedChoicesApplied`), makes a feed sale entry by the one `FeedEntry.record_sale` rule, carrying its order, unique per order; the feed readers price it from the order and the live feed broadcasts it, with a listing sale's visibility.
- **Files:**
  - `db/migrate/20261123150000`, `150001`, `150002` -- `order_id` with its foreign key and the new sale reference check (not valid), the concurrent unique index per order, then validation and the old sale check dropped; `db/schema.rb` regenerated.
  - `feed_entry.rb` -- `record_sale` takes `listing_id:` or `order_id:`.
  - `sale_feed.rb`, `event_store.rb` -- `SaleFeed` hears `OrderServed` and `WantedChoicesApplied`.
  - `feed_entries.rb`, `new_feed_entries.rb` -- order price, `order_ids:`.
  - `live_stream.rb`, `live_feed_job.rb` -- an order's notice and its live broadcast.
  - Tests: `order_sale_feed_test.rb` (new), `live_feed_sale_test.rb`, `market_feed_test.rb` (system), `test/support/market.rb`.
- **Review:** none, no lenses launched (the author's choice for this epic).
- **Verification:** targeted tests (order and listing sale feed, live feed jobs, `SellToOrder`, `ApplyWantedChoices`, feed) 105 runs green; the implementer also ran `test/domains`, `test/jobs`, `test/models` (3698 runs green); schema regenerated from the migrations on Postgres 18 is identical to `db/schema.rb`; zeitwerk, packwerk, planning-id, file-size checks and rubocop pass. The system test was not run.
- **Residual risks:** the new system test is unrun (it expects two "Sam" names under VENTES and "Bought for 300"); a private player's direct sales show in the feed, as a listing's sale does (the ticket's open question, settled that way).
