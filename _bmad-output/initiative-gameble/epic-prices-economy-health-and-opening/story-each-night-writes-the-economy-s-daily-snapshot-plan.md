---
title: 'Each night writes the economy''s daily snapshot'
type: 'feature'
ticket: '41.2'
created: '2026-11-10'
status: 'built'
baseline_revision: '24beb5709830e77166d8cc9167727d33f5bacbd5'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Nothing records the economy day by day, so no indicator can be read and no alert derived. Epic requirements R7 to R11.

**Approach:** A migration adds one snapshot row per UTC day. `EditionPrice.rarity_average` gives a rarity's price. `WriteDailySnapshot` computes the day's figures and writes the row once. `ReconcileWalletsJob` reads the previous day's closing circulation inside its REPEATABLE READ read and writes the snapshot after the price refresh, even when the reconciliation finds a difference.

## Boundaries & Constraints

**Always:**
- The operation takes the day, the closing circulation and the reconciliation's result as arguments and never reads the clock, so a seed can call it per day.
- Created is the day's `mint` entries; destroyed is the day's `stamp`, `commission` and `forfeit` entries, forfeited being the `forfeit` part of it; a day is a UTC day over `created_at`.
- A player is active when a pack of theirs was opened (`opened_at`) in the period; earnings are `mint` plus `sale` plus `commission` deltas (commission is negative); the median is over the day's active players with positive earnings, null when none.
- A rarity's average is the median of its edition rows with at least the minimum sale count, null when none; a missing figure is null, never 0.
- A second run for a day, and a day before the first opening (settings' `first_opened_at`, or no settings), write nothing and publish nothing; one run publishes `DailySnapshotWritten` once, inside the transaction.
- The migration is an expand: a new table, its unique index inside the create, no change to any existing table.

**Never:** a reader of the snapshots (story 5), a chart, an alert, a recurring entry change, a seed, a write to `db/schema.rb`.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- Money columns are bigint, the share is an integer in basis points, PiCoins per active player is the closing circulation divided by the players active over the 90 days ending with the day, rounded down, null with no active player.
- The median of an even count is the mean of the two middle values rounded down.
- The top 1% are the richest `ceil(n / 100)` of the `n` wallets holding PiCoins (available plus committed); the share is read when the snapshot is written, at 00:10 UTC, and is null when no wallet holds any.
- The reconciliation result is three columns: balanced, the number of wallet differences and the circulation difference.
- The operation returns the snapshot it wrote, and nil when it wrote nothing; the job takes the day as the UTC day before `now` and the cutoff as `now`'s UTC midnight.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First write | Market opened, day with mints, stamps, sales, commissions | One row with every figure, event published once | No error expected |
| Rerun | Row exists for the day | Row and event count unchanged | No error expected |
| Before the opening | Day before `first_opened_at`, or no settings | Nothing written | No error expected |
| Chain | Consecutive days | Each circulation equals the previous plus created less destroyed | No error expected |
| No earner | No active player with positive earnings | Median null | No error expected |
| No price | No rarity row with enough sales | Rarity average null | No error expected |
| Reconciliation differs | Job finds a difference | Snapshot still written, result columns say so | Difference reported as before |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/reconcile_wallets.rb`, `models/game/market/reconciliation.rb` -- the read the closing circulation joins.
- `app/domains/game/app/jobs/game/reconcile_wallets_job.rb` -- runs the snapshot after the refresh.
- `app/domains/game/app/models/game/market/edition_price.rb` -- gains `rarity_average`.
- `app/domains/game/app/operations/game/market/refresh_edition_prices.rb` -- model of an operation with no player.
- `app/domains/game/app/events/game/market/settings_changed.rb` -- model of an event with a stream constant.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/20261110190000_create_game_market_daily_snapshots.rb`, `DailySnapshot` -- the table and its model
- [ ] `EditionPrice.rarity_average`
- [ ] `DailyFigures`, `WriteDailySnapshot`, `DailySnapshotWritten`
- [ ] `ReconcileWallets`, `Reconciliation`, `ReconcileWalletsJob` -- closing circulation and the call after the refresh
- [ ] Tests: operation, figures chain, rarity average, job

**Acceptance Criteria:**
- Given the market opened and a series of days with mints, stamps, sales, commissions and a forfeit, when the snapshots are written day by day, then each circulation equals the previous plus created less destroyed and equals the reconciliation's sum.

## Implementation Notes

Built as planned; nothing was run. `Median` is shared by the rarity average and the earnings median. `ReconcileWallets.call(cutoff:)` reads the closing circulation in its own snapshot and `Reconciliation` carries it as `circulation_before_cutoff`, nil without a cutoff. `DailyFigures` holds the ledger, pack and wallet reads; the operation only guards, assembles and publishes. The snapshot table's rows are read-only once persisted.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
