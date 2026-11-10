---
title: "The Archives' stocks are summed every hour"
type: 'feature'
ticket: '12'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: 'f7f4f3d2183e8f913b76e70bed07fa8b99192a20'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Entrusting writes one deposit row per player and card-season, but nothing yet answers "how many copies of this edition do the Archives keep"; a stock row written on every entrustment would queue every player on one hot row.

**Approach:** A new table `game_market_archive_stocks` holds one row per card-season. `Game::Market::SumArchiveStocks`, an `ApplicationOperation` writing rows that belong to no player, replaces the stocks from the deposits' sums in the database; `Game::ArchiveStocksJob` runs it every hour in both blocks of `config/recurring.yml`. Covers R3.

## Boundaries & Constraints

**Always:** sums are computed by the database in set-based statements, never by loading deposit rows; the operation is idempotent, and a row whose quantity is unchanged is not rewritten (its `updated_at` stays); a stock row exists only for a card-season with at least one deposited copy (`quantity > 0` check); deposits are only read, so a deleted player's anonymised rows keep counting with no handler change; the job is in the `development` and `production` blocks of `config/recurring.yml`, queue `default`, `every hour`; the migration follows expand/contract (a new table, foreign key to `catalog_card_seasons`, unique index on the card-season); no planning id in code.

**Never:** a stock row written by `EntrustCards` or by any per-player path; a deposit removed or changed on account deletion; a player id in the stock table; any reader, page or indicator of the stocks (later stories); a published event (the sum is derived data, like the weekly goal's total); hand-editing `db/schema.rb`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two players, one card-season | deposits 3 and 4 of card-season A | one stock row for A with quantity 7 | No error expected |
| Second run | nothing changed since the last run | no row inserted, updated or deleted; `Success(0)` | No error expected |
| New deposit | a later entrustment adds copies to A | next run raises A's stock; unchanged cards are untouched | No error expected |
| Deleted player | a player who deposited 5 of A is deleted through `Accounts::DeletePlayer` | deposits remain, the stock still counts the 5 | No error expected |
| No deposit | no deposit row at all | no stock row, `Success(0)` | No error expected |
| Orphan stock | a stock row for a card-season with no deposit | the run deletes it | No error expected |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/archive_deposit.rb` -- the per-player deposits (`game_market_archive_deposits`, unique per player and card-season, `quantity > 0`); the source of the sums and the model style to copy.
- `db/migrate/20261110090000_create_game_market_tables.rb` -- the deposits table and its foreign keys; shows how market tables are declared (`t.references ... foreign_key: { to_table: ... }`, named unique index, check constraint).
- `app/domains/game/app/operations/game/sum_weekly_goal.rb` and `app/domains/game/app/jobs/game/sum_weekly_goal_job.rb` -- the closest precedent: a derived total summed by a plain `ApplicationOperation` with no player, set-based SQL, run by a recurring job; `Game::Operation` is not usable because it requires `player:`.
- `app/domains/game/app/jobs/game/reconcile_wallets_job.rb` -- job style for the market (`ActiveJob::Base`, `queue_as :default`).
- `app/domains/game/app/operations/game/market/entrust_cards.rb` -- the writer of deposits (via `ArchiveDeposit.add`); unchanged, and proof that entrusting writes no stock.
- `app/domains/accounts/app/operations/accounts/delete_player.rb` -- anonymises the player row only; deposits are untouched, so the deleted-player test calls it directly.
- `config/recurring.yml` -- anchors then `development:` and `production:` blocks; add one anchor and reference it in both.
- `test/config/recurring_reconcile_wallets_test.rb` -- pattern for a recurring-config test needing no database.
- `test/domains/game/weekly_goal_operations_test.rb` -- pattern for testing a summing operation; `test/domains/game/market/entrust_cards_test.rb` with `test/support/{holdings,market}.rb` -- how to produce real deposits through `EntrustCards`.
- `architecture-gameble.md` AD-43 (stocks summed by a periodic job), AD-9 (no row written by every player), AD-14 (players anonymised, never deleted), AD-10 (derived data, housekeeping writes publish nothing).

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261110100012_create_game_market_archive_stocks.rb` -- create `game_market_archive_stocks`: `card_season` reference (not null, foreign key to `catalog_card_seasons`, unique index named `index_game_market_archive_stocks_uniqueness`), `quantity` integer not null with check `quantity > 0`, `created_at`, `updated_at`; a new table needs no concurrent index -- the stored sum
- [ ] `app/domains/game/app/models/game/market/archive_stock.rb` -- `Game::Market::ArchiveStock < ApplicationRecord` on the table, with a one-line class comment saying it is a derived sum of the deposits and no per-player write touches it -- the model
- [ ] `app/domains/game/app/operations/game/market/sum_archive_stocks.rb` -- `SumArchiveStocks < ApplicationOperation` (not `Game::Operation`), `call(now: Time.current)`: in one `transaction`, run `INSERT INTO game_market_archive_stocks ... SELECT card_season_id, SUM(quantity), now, now FROM game_market_archive_deposits GROUP BY card_season_id ORDER BY card_season_id ON CONFLICT (card_season_id) DO UPDATE SET quantity = EXCLUDED.quantity, updated_at = EXCLUDED.updated_at WHERE game_market_archive_stocks.quantity <> EXCLUDED.quantity`, then delete stocks whose card-season has no deposit; return `Success(changed_rows)` (rows inserted, updated or deleted), publishing no event -- the sum
- [ ] `app/domains/game/app/jobs/game/archive_stocks_job.rb` -- `Game::ArchiveStocksJob`, queue `default`, `perform(now: Time.current)` runs the operation with `.value!` and returns its value -- the hourly run
- [ ] `config/recurring.yml` -- anchor `sum_archive_stocks` (`class: Game::ArchiveStocksJob`, `queue: default`, `schedule: every hour`) with a one-line comment, referenced in `development` and `production` -- the schedule
- [ ] `test/domains/game/market/sum_archive_stocks_test.rb` -- deposits made through real `EntrustCards` calls by two players for one card-season sum into one stock row; a second run returns `Success(0)` and leaves `updated_at` as it was; a later entrustment moves only that card's stock; a player deleted through `Accounts::DeletePlayer` keeps counting and the deposit rows remain; an orphan stock row is deleted; no deposit gives no stock; `EntrustCards` alone writes no stock row -- covers the matrix
- [ ] `test/domains/game/archive_stocks_job_test.rb` -- the job runs the operation (stocks reflect the deposits after `perform_now`) and queues on `default` -- covers the job
- [ ] `test/config/recurring_archive_stocks_test.rb` -- both `development` and `production` carry `{ "class" => "Game::ArchiveStocksJob", "queue" => "default", "schedule" => "every hour" }` under `sum_archive_stocks`; reads `config/recurring.yml` only -- schedule check

**Acceptance Criteria:**
- Given two players' deposits of one card-season, when the job runs, then one stock row for that card-season holds their sum.
- Given nothing changed, when the job runs again, then no stock row changes, including its `updated_at`.
- Given a player is deleted, when the job runs, then the stock still counts that player's deposits.
- Given `config/recurring.yml`, when read for development and production, then the job is scheduled every hour on queue `default` in both.
- Given `EntrustCards` runs, when it finishes, then `game_market_archive_stocks` is unchanged until the job runs.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Decisions settled without a checkpoint:

- The operation extends `ApplicationOperation` directly, as `SumWeeklyGoal` does: `Game::Operation` demands a `player:`, and these rows belong to no player. It lives in `operations/game/market/`, the job at `Game::ArchiveStocksJob` beside the other game jobs (the architecture's name is the class's base name).
- No event is published: the stocks are derived from deposits that `CardsEntrusted` already announced, and AD-10 exempts housekeeping sums; nothing could consume an hourly "stocks summed" event.
- The upsert is a single set-based statement guarded by `WHERE quantity <> EXCLUDED.quantity`, so an unchanged hour writes nothing and the row count it returns is the number of real changes; rows are ordered by card-season so two overlapping runs lock in the same order.
- Deposits never decrease, so the orphan-deletion step only guards a restored or repaired database; it is cheap and keeps the table equal to the sums.
- The migration is a plain `create_table`: strong_migrations allows a new table, whose index and foreign key are born with it.
- No reader of the stocks is added; resale is designed when built (AD-43).

## Verification

**Commands:**
- `bin/rails test test/domains/game/market/sum_archive_stocks_test.rb test/domains/game/archive_stocks_job_test.rb test/config/recurring_archive_stocks_test.rb test/domains/game/market/ledger_write_guard_test.rb` -- pass
- `bundle exec rubocop` on touched files, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references` -- clean
- `db/schema.rb` is regenerated from the migrations at the end of the run, not edited here.
