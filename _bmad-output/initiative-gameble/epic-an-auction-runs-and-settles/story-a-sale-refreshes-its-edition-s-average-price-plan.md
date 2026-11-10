---
title: 'A sale refreshes its edition''s average price'
type: 'feature'
ticket: '39.3'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '579532637b130be63c1c49b044afb9ff5190069e'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/epic-an-auction-runs-and-settles.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-an-auction-runs-and-settles/story-a-due-auction-closes-and-settles-exactly-once-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A sale settles but leaves no trace of what its edition now costs: there is no stored average price per card-season and a sold listing does not remember the average it produced. Epic requirement R10; epic 41 reads the table for display, the nightly refresh and `rarity_average`.

**Approach:** `game_market_edition_prices` holds one row per card-season (average and sales used), `game_market_listings` gains `average_after_sale`, and `Game::Market::EditionPrice` is the only formula. The settlement step of story 2 upserts and locks the row after the holdings and player states and before the ledger post, recomputes it from the current version's window, and stores the new average on the sold listing.

## Boundaries & Constraints

**Always:**
- `EditionPrice` is the only formula: the sold listings of the card-season whose `sold_at` is inside the current settings version's `average_window_days` (counted back from the settlement's `now`), newest first by `sold_at` then `id`, at most `average_sale_count` of them, read from `final_price`. With 3 or more sales the highest and the lowest are dropped; with fewer none is dropped; the mean of the rest is floored to an integer (`Integer#div`, no float). No sale in the window gives `average` nil and `sales_used` 0. `sales_used` is the number of sales read, before any drop.
- The "none dropped under 3" threshold is one constant, `EditionPrice::MINIMUM_SALES = 3`, the figure epic 41 reuses for "few sales" and `rarity_average`.
- Lock order follows the architecture: bank locks, listing, holdings, player states (the allocation), then the edition price row, then `Ledger.post` last. The row is upserted (`insert_all`, `unique_by: :card_season_id`, nothing on conflict), then locked with `FOR UPDATE`, and only then are the sales read, so two settlements of one edition in turn each see the other's committed sale.
- The step runs inside `AuctionSettlement#settle_sale`, after the listing is marked `sold` with `sold_at` and `final_price` (the sale counts in its own window) and before the entries are returned; it posts nothing and publishes nothing. `settle_sale` is the one settlement of both the close and the buy-now of the bidding story, so both refresh the row. `average_after_sale` is the row's new average, stored on the sold listing in the same transaction.
- Schema changes are expand only and in separate migrations: the new table, the new nullable column, the concurrent index.
- Only operations write the row and the column; no planning id in code or tests; English outside `fr.yml`; no database id leaves the server.

**Never:**
- No nightly refresh, no `rarity_average`, no display of the average on any screen (the Annonce, Mettre en vente, card detail), no sort or filter by average, no chart query, no change to `AuctionSold`, no new locale key, no new Failure code: epic 41.
- No backfill of `average_after_sale` for listings sold before this story (none can be sold in production: the market ships closed).
- No `db/schema.rb` edit by hand; no second formula anywhere (no SQL average, no computation in a handler or a view).

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The settings in force for the window and the sale count are `CurrentSettings.call` read at refresh, as AD-47 and the ticket say "the current version", not the listing's own version.
- `EditionPrice` is an ActiveRecord model on the new table carrying the formula and the row access (`EditionPrice.average_of(prices)`, `EditionPrice.sales_in_window`, `EditionPrice.lock_row`), like `Ledger` and `Listing` sit beside their operations; the write itself is the private step `refresh_edition_price` in the `AuctionSettlement` mixin, so story 4's buy-now gets it by calling `settle_sale`.
- `average` is nullable and `sales_used` defaults to 0: the row exists after the upsert before the sales are read, and epic 41's nightly refresh can leave a row with no sale in the window. A check keeps `average` null exactly when `sales_used` is 0.
- A row also stores `refreshed_at`, the `now` of the last computation, so the nightly job of epic 41 can find the rows whose window moved without a new migration.
- The concurrent index on sold listings by card-season and `sold_at` serves this read and epic 41's `EditionSales`; it is partial on `status = 'sold'`.
- Ties on `sold_at` are broken by listing `id` descending, so the formula is deterministic.
- `MINIMUM_SALES` equals the lower bound of the `average_sale_count` setting (3), so a version can never ask for fewer sales than the drop rule needs; a test pins the two together.
- No locale key and no `Failure` code is added: a refresh cannot refuse, and a deadlock inside it already answers `market_busy` through the close and, later, the buy-now.
- The story's lock-order proof is a test over the SQL the settlement issues (the edition row's `FOR UPDATE` after the holdings and before the wallet lock), not a timing race.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| One sale | Settlement is the edition's first sale at 10,000 | Row average 10,000, `sales_used` 1; listing `average_after_sale` 10,000 | No error expected |
| Two sales | Sales 10,000 and 20,000 | Average 15,000 (none dropped), `sales_used` 2 | No error expected |
| Three sales | 10,000, 20,000, 30,000 | Highest and lowest dropped: 20,000, `sales_used` 3 | No error expected |
| Five sales | 10,000, 12,000, 15,000, 18,000, 40,000 | Drop 10,000 and 40,000: floor(45,000 / 3) = 15,000, `sales_used` 5 | No error expected |
| Six sales | Six sales in the window, count setting 5 | Only the 5 newest are read; the oldest is ignored | No error expected |
| Sale outside the window | A sale older than the window days, plus one new sale | The old one is ignored; `sales_used` counts the new one only | No error expected |
| Floor | Rest averages 15,000.67 | 15,000 stored | No error expected |
| Settings changed | Count or window changed by a new version | The next settlement reads the new version's values | No error expected |
| Two settlements in turn | Two listings of one edition settle one after the other | The row matches the formula over both; the first listing keeps the average it produced, the second its own | No error expected |
| Different editions | Sales of two card-seasons | Each has its own row; neither moves the other | No error expected |
| Close run twice | A second close of the same listing | Row, `average_after_sale` and sales unchanged (the close already refuses) | `Failure(:listing_not_closable)` |
| Non-sold end | Unsold or withdrawn close | No row written, no column set | No error expected |
| Deadlock | `ActiveRecord::Deadlocked` during the step | Rolled back, nothing stored | `Failure(:market_busy)` |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/auction_settlement.rb` -- `settle_sale` runs `lock_sale_holdings`, the allocation, the two `move`s and the tiers, then `listing.update!(status: "sold", ...)` and returns `sale_entries`; the new step goes between the update and `sale_entries`, so after the allocation took the player states.
- `app/domains/game/app/operations/game/market/close_auction.rb` -- calls `settle_sale` from `sell` then makes the single `Ledger.post`; unchanged by this story, but the non-sold branches (`end_without_sale`) must not reach the step.
- `app/domains/game/app/models/game/market/listing.rb` -- gains a `sold` scope; `sold_at`, `final_price`, `status` already exist.
- `app/domains/game/app/models/game/market/settings.rb`, `settings_rules.rb`, `starting_settings.rb` -- `average_sale_count` (3..20, starts 5) and `average_window_days` (7..365, starts 90) already exist on every version.
- `app/domains/game/app/queries/game/market/current_settings.rb` -- the version in force, read every time.
- `app/domains/game/app/models/game/market/ledger.rb`, `wallet.rb` -- model for a table-backed module with `insert_all(... unique_by:)`; the ledger's own lock sits last.
- `app/domains/game/app/models/game/trade_locks.rb` -- holdings are locked by `TradeLocks.holdings`, before this row.
- `db/migrate/20261110120000_create_game_market_listings.rb`, `20261110120001_add_open_ends_at_index_to_game_market_listings.rb` -- shape of the table and of a concurrent partial index migration.
- `test/support/market.rb`, `market_listings.rb`, `market_auctions.rb` -- `open_market!`, `listing!` (it takes no `sold_at` or `final_price`, hence the new helper), `fund!`, `lead!` to reuse; a new support file adds sold listings.
- `app/domains/game/app/models/game/market/settings_rules.rb` -- `RANGES[:average_sale_count]` (3..20) and `RANGES[:average_window_days]` (7..365): the bounds the formula can meet.
- `test/domains/game/market/close_auction_test.rb` -- the worked-example close, extended with the stored average.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261110130000_create_game_market_edition_prices.rb` -- create `game_market_edition_prices`: `card_season` reference (not null, unique index, foreign key to `catalog_card_seasons`), `average` bigint null, `sales_used` integer not null default 0, `refreshed_at` datetime, timestamps, checks `sales_used >= 0`, `average IS NULL OR average >= 0` and `(average IS NULL) = (sales_used = 0)` -- the one row per card-season of the ticket
- [ ] `db/migrate/20261110130001_add_average_after_sale_to_game_market_listings.rb` -- add nullable `average_after_sale` bigint -- the average a sold listing produced
- [ ] `db/migrate/20261110130002_add_sold_card_season_index_to_game_market_listings.rb` -- `disable_ddl_transaction!`, concurrent partial index on `(card_season_id, sold_at)` where `status = 'sold'` -- serves the window read
- [ ] `app/domains/game/app/models/game/market/edition_price.rb` -- new model on the table: `MINIMUM_SALES`, `average_of(prices)` returning the floored average with the drop rule (nil for none), `sales_in_window(card_season_id, settings:, now:)` returning the newest `final_price` values, `lock_row(card_season_id)` upserting then locking the row -- the only formula
- [ ] `app/domains/game/app/models/game/market/listing.rb` -- add `scope :sold, -> { where(status: "sold") }` -- shared by the window read and later readers
- [ ] `app/domains/game/app/operations/game/market/auction_settlement.rb` -- add private `refresh_edition_price(listing, now)`: lock the row, read the sales with `CurrentSettings.call`, update `average`, `sales_used`, `refreshed_at`, then `listing.update!(average_after_sale:)`; call it in `settle_sale` after `publish_tiers` and the listing's `sold` update, before `sale_entries` -- the settlement step; keep the file under 400 lines
- [ ] `test/support/market_sales.rb` -- new helper `sold!(card_season, price, sold_at:)` creating a sold listing row directly (seller from fixtures, `final_price`, `sold_at`, status `sold`) -- arrangement of the formula tests, a file of this story's own
- [ ] `test/domains/game/market/edition_price_test.rb` -- formula tests (`MINIMUM_SALES` equal to the setting's lower bound included): `average_of` with 0, 1, 2, 3, 5 and 6 prices and the floor; `sales_in_window` with the count setting, a sale just outside the window, tie order, another edition's sales ignored, a changed settings version
- [ ] `test/domains/game/market/edition_price_settlement_test.rb` -- operation tests through `CloseAuction`: a settlement writes the row (`average`, `sales_used`, `refreshed_at`) and the listing's `average_after_sale`; two settlements of one edition in turn leave the row matching the formula and each listing its own average; two editions are independent; an unsold and a withdrawn close write no row and no column; a second close changes nothing; a deadlock stores nothing; the SQL of one settlement locks the holdings, then the edition row, then the wallets, in that order
- [ ] `test/domains/game/market/close_auction_test.rb` -- worked-example test also asserts the sold listing's `average_after_sale` equals the single sale's price -- keeps story 2's test honest with the new step

**Acceptance Criteria:**
- Given an edition with no sale, when its first listing settles at a price, then `game_market_edition_prices` holds one row for it with that average, `sales_used` 1, and the listing's `average_after_sale` is that price.
- Given sales of 10,000, 12,000, 15,000, 18,000 and 40,000 in the window, when the formula runs, then the stored average is 15,000 with `sales_used` 5; given six sales and a count setting of 5, only the five newest count.
- Given a sale older than the window days, when the next sale settles, then the old sale is not counted.
- Given two settlements of the same edition one after the other, when both commit, then the row equals the formula over both sales and the first listing still shows the average it produced.
- Given a settlement, when it runs, then the edition row is locked after the holdings and before any wallet, and `Ledger.post` is still the last write.
- Given an unsold, withdrawn or already closed listing, when the close runs, then no edition row or `average_after_sale` changes.
- Given the migrations, when the schema is regenerated from them on Postgres 18, then it carries the table, the column and the index, with no hand edit.

## Implementation Notes

## Plan Change Log

- 2026-11-10, approver: reviewed against the lock order, the migrations (all sort after `20261110120005`, the newest on the branch, and no other pending plan adds one) and the ticket; no change needed. Build note: the window start is exclusive (`sold_at > now - average_window_days days`), and the "sale just outside the window" test pins it.

## Review Triage Log

## Design Notes

- The step relies on the sale being already in `game_market_listings` when the sales are read, which is why it follows the listing's `sold` update; the row's lock, not the listing's, is what serialises two sales of one edition.

```ruby
def average_of(prices)
  return if prices.empty?
  kept = prices.size >= MINIMUM_SALES ? prices.sort[1...-1] : prices
  kept.sum.div(kept.size)
end
```

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file -- expected: no offence
- `bundle exec packwerk check` -- expected: no violation
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market/edition_price_test.rb test/domains/game/market/edition_price_settlement_test.rb test/domains/game/market/close_auction_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
- `bin/rails zeitwerk:check` -- expected: pass
- After the migrations: regenerate `db/schema.rb` as CI does -- expected: no drift (done at the end of the market build)
