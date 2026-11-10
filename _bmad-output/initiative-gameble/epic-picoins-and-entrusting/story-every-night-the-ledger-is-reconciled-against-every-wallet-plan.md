---
title: 'Every night the ledger is reconciled against every wallet'
type: 'feature'
ticket: '11'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '5ef2bb5aeadbcc785f3862f3f39493d3becb3773'
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

**Problem:** Wallets and the insert-only ledger can drift apart (a balance changed outside `Ledger.post`, an entry written with no wallet) and nothing would notice; PiCoins could be created or lost unseen.

**Approach:** A read-only `Game::Market::ReconcileWallets` compares, in one `REPEATABLE READ` read, each wallet with the sum of its entries and the sum of all deltas with minted less stamps, commissions and forfeits, and returns the result. `Game::ReconcileWalletsJob` runs it at 00:10 UTC and reports every difference to the error tracker with the players concerned; no balance is touched. Covers R14.

## Boundaries & Constraints

**Always:** the query reads only (no write, no lock, no balance repair); every read of one run happens inside one `REPEATABLE READ` transaction; sums are computed by the database, never by loading rows; the job is in the `development` and `production` blocks of `config/recurring.yml`, queue `default`, `every day at 12:10am` (UTC, the app's recurring clock); the job returns the query's result so the epic 41 steps can read it; amounts are integers; no planning id in code.

**Never:** repairing, adjusting or blocking anything on a difference; the edition price refresh, `WriteDailySnapshot`, daily circulation per day or any indicator (epic 41); an operation or an event (nothing is written); a new table or migration; a per-player error without the players concerned.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|---|---|---|---|
| Balanced | wallets equal their entries, circulation equals minted less destroyed | empty differences, `balanced?` true | job reports nothing |
| Wallet drifted | a wallet changed outside `Ledger.post` | one wallet difference naming the player, wallet and entry sums | job reports it, balance untouched |
| Entry without wallet | an entry inserted for a player with no wallet row | one difference for that player, wallet zero | reported |
| Wallet without entries | a nonzero wallet and no entry | one difference for that player | reported |
| Circulation off | sum of all deltas differs from minted less stamps, commissions, forfeits | circulation difference | reported once, no player |
| Empty market | no wallet, no entry | balanced, all totals zero | nothing reported |
| Concurrent post | a `Ledger.post` commits during the read | the read sees one snapshot, never half | no false report |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/ledger.rb` -- single writer; per player `available`/`committed` equal the sum of entry deltas by construction; this is the invariant checked.
- `app/domains/game/app/models/game/market/{wallet,ledger_entry}.rb` -- tables `game_market_wallets`, `game_market_ledger_entries` (kinds `mint stamp hold release purchase sale commission forfeit`); stamps, commissions and forfeits are negative `available_delta`.
- `app/domains/game/app/queries/game/market/current_settings.rb` -- shape of a market query module (`def self.call`).
- `app/domains/game/app/jobs/game/expire_trades_job.rb`, `heal_banks_job.rb` -- job style (`ActiveJob::Base`, `queue_as :default`, `Rails.error.report(error, context:)`).
- `config/recurring.yml` -- anchors then `development:` and `production:` blocks; add the job to both.
- `test/jobs/sync_steam_libraries_job_test.rb:13` -- pattern asserting `recurring.yml` entries per environment.
- `test/domains/game/trade_concurrency_test.rb` -- pattern for `use_transactional_tests = false` with teardown; `test/support/market.rb` (`open_market!`) for the settings row entries need.
- `test/domains/game/market/ledger_write_guard_test.rb` -- scans `app/` for wallet/entry writes: the query and job must contain none (reads only).
- `architecture-gameble.md` AD-41 (nightly check), AD-48 (the reconciliation runs first, circulation read in its snapshot, job order).

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/reconciliation.rb` -- `Reconciliation = Data.define(:wallet_differences, :minted, :destroyed, :circulation, :read_at)` with `WalletDifference` (`player_id`, `wallet_available`, `wallet_committed`, `entries_available`, `entries_committed`), `circulation_difference` (`circulation - (minted - destroyed)`), `balanced?`; plus the error classes nested inside the value, `Game::Market::Reconciliation::WalletMismatch` and `Game::Market::Reconciliation::CirculationMismatch` (`StandardError`), so the file defines only `Game::Market::Reconciliation` and Zeitwerk resolves them -- the value epic 41 reads
- [ ] `app/domains/game/app/queries/game/market/reconcile_wallets.rb` -- `ReconcileWallets.call`: one `ActiveRecord::Base.transaction(isolation: :repeatable_read, joinable: false)`; statement 1 full-outer-joins wallets with entries grouped by player and keeps rows where either delta sum differs (covers drifted wallet, entry without wallet, wallet without entries); statement 2 returns `sum(available_delta + committed_delta)`, `minted` (kind `mint`) and `destroyed` (`-sum` of kinds `stamp commission forfeit`); build and return a `Reconciliation` -- the read
- [ ] `app/domains/game/app/jobs/game/reconcile_wallets_job.rb` -- `Game::ReconcileWalletsJob`, queue `default`: call the query; for each wallet difference `Rails.error.report(Game::Market::Reconciliation::WalletMismatch.new(...), handled: true, context: { player_id:, wallet_available:, ... })`; for a circulation difference report one `Game::Market::Reconciliation::CirculationMismatch` with the three totals; return the result; touch nothing else -- the report
- [ ] `config/recurring.yml` -- anchor `reconcile_wallets` (`class: Game::ReconcileWalletsJob`, `queue: default`, `schedule: every day at 12:10am`) with a one-line comment, referenced in `development` and `production` -- the schedule
- [ ] `test/domains/game/market/reconcile_wallets_test.rb` -- `use_transactional_tests = false` with a teardown clearing wallets, entries and the settings it made: balanced after real `Mint.credit` and a stamp/hold/purchase/sale/commission series; wallet changed by `Wallet.update_all` outside `Ledger.post`; `LedgerEntry.insert_all!` with no wallet; wallet with no entries; circulation off with a balanced per-wallet view; empty market; concurrent post: a `sql.active_record` subscriber, after the first statement of the read, runs a `Ledger.post` in another thread (own connection) and joins it, so it commits between the two statements; the result must not contain that post (a READ COMMITTED read would), which is the test covering the "Concurrent post" row and the isolation level, with no reliance on transaction-begin SQL being published; no write statement issued -- covers the matrix
- [ ] `test/domains/game/reconcile_wallets_job_test.rb` -- `use_transactional_tests = false` (the real query opens a `REPEATABLE READ` transaction with `joinable: false`, which Rails refuses inside a test transaction) with a teardown clearing wallets, ledger entries and the settings it created, as in `trade_concurrency_test.rb`; matching wallets report nothing (`assert_no_error_reported`); a drifted wallet and an entry without wallet are each `assert_error_reported` with the player in the context; a circulation difference is reported once; balances unchanged after the run; the job returns the result -- covers the job
- [ ] `test/config/recurring_reconcile_wallets_test.rb` -- both `development` and `production` carry the job, class `Game::ReconcileWalletsJob`, queue `default`, schedule `every day at 12:10am` -- schedule check; reads `config/recurring.yml` only and needs no database

**Acceptance Criteria:**
- Given wallets built only through `Ledger.post`, when the job runs, then nothing is reported and no balance changes.
- Given a wallet raised outside `Ledger.post`, when the job runs, then the error tracker receives a report naming that player and the wallet is left as it was.
- Given an entry inserted for a player with no wallet, when the job runs, then that player is reported.
- Given the ledger write guard, when it scans `app/`, then the new files do not trip it.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Decisions settled without a checkpoint (consistent with the spec, AD-41, AD-48 and the epic's contract with epic 41):

- The query lives in `queries/game/market/` and the job at `Game::ReconcileWalletsJob` beside `Game::ExpireTradesJob`; the architecture's name `ReconcileWalletsJob` is the class's base name.
- The query returns a value, and the job reports: tests can read differences without an error tracker, and epic 41 reads the same value without a second query.
- A wallet is compared on both columns with the sum of its entries' deltas; the global check compares `sum(available + committed)` of all entries with minted less stamps, commissions and forfeits, since `purchase` and `sale` move PiCoins between players and `hold`/`release` only between a player's columns.
- Circulation per UTC day is not computed here: epic 41 extends the query inside the same snapshot; this story hands over all-time totals only.
- The tracker gets one report per drifting player (player id in the context) plus one for the global difference; ids are fine there, the tracker is not a URL or HTML.
- `every day at 12:10am` is the recurring clock, which AD-50's other jobs already read as UTC.
- The query test and the job test (which runs the real query) are non-transactional, both with a teardown that clears what they created: Rails refuses an isolation level inside the test transaction. The recurring-config test touches no database.
- The error classes are nested in `Reconciliation` so `reconciliation.rb` defines one constant and autoloads; the job names them by full name.
- The isolation level is verified by behaviour, not by SQL text: the concurrent-post test (a post committed from another thread between the two statements must not appear) is the assertion for the matrix row, since Rails 8.1 may not publish transaction-begin SQL on `sql.active_record`.

## Verification

**Commands:**
- `bin/rails test test/domains/game/market/reconcile_wallets_test.rb test/domains/game/reconcile_wallets_job_test.rb test/config/recurring_reconcile_wallets_test.rb test/domains/game/market/ledger_write_guard_test.rb` -- pass
- `bundle exec rubocop` on touched files, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references` -- clean
