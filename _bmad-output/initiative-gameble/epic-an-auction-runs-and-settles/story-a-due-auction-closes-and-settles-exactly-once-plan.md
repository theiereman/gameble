---
title: 'A due auction closes and settles exactly once'
type: 'feature'
ticket: '39.2'
created: '2026-11-10'
status: 'built'
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

**Problem:** A listing can be created and shown but never ends: nothing closes a due auction, so no winner gets the copy, no seller is paid, an unbid copy stays reserved for good and the commission is never destroyed. Epic requirements R4 (commission use), R8, R9, R11, R12 (settlement half of R9: the edition price refresh is story 3's).

**Approach:** `Game::Market::CloseAuction` rechecks under the bank locks and the listing lock, then sells (through a shared settlement step that story 4's buy-now reuses), leaves unsold, or withdraws. `CloseDueAuctionsJob` runs it once per due listing every 10 seconds; `OldestDueListing` and `CheckMarketHealthJob` report a stuck close. `AuctionSold` reaches `GoalsReached`, `Achievements` and the balance notice, never the weekly contribution.

## Boundaries & Constraints

**Always:**
- `CloseAuction(player: seller, listing_id:)` is the only closer; one listing per transaction. It reads seller and leader unlocked, takes their bank locks in ascending player id (`TradeLocks.players`), locks the listing, reads `now`, and rechecks open, due (`ends_at <= now`) and the same leader; otherwise it changes and publishes nothing and answers `Failure(:listing_not_closable)`. Removal (`banned_at` or `deleted_at`) is read from the players after the bank locks.
- Lock order follows AD-10: bank locks, listing, holdings by ascending player then card-season, player states (the allocation), then `Ledger.post` once, last. A deadlock answers `Failure(:market_busy)`.
- Branches, in this precedence: removed seller gives `withdrawn` (the leader's whole maximum released, the leader cleared); no leader gives `unsold`; removed leader gives `unsold` (maximum released, leader cleared); otherwise `sold`. Every non-sold end releases the seller's `reserved` on the copy.
- The sold path settles at `current_price`: the winner's allocation is received (published season read once, after the bank locks), one copy moves with its `reserved` through `MoveHoldings#move`, set tiers are recorded with `reached_by: "trade"` and their events published, the seller's unheld showcase entries are removed, the listing gets `sold`, `sold_at`, `final_price`. The step returns entries and posts nothing: `purchase` (winner, committed minus the price), `release` of the surplus (maximum minus price, winner), `sale` (seller, the full price) and `commission` (seller, `AuctionMath.commission(price, version.commission_basis_points)` of the listing's own settings version); zero amounts emit no entry. The commission is destroyed (no counterpart entry).
- `CloseAuction` makes the single `Ledger.post` and publishes exactly one event per close: `AuctionSold`, `AuctionUnsold` or `ListingWithdrawn`, identifiers and amounts only. The weekly contribution never hears `AuctionSold`.
- Every Failure code has an `errors.game.<code>` key in `en.yml` and `fr.yml`; no database id leaves the server; no planning id in code or tests; English only outside `fr.yml`; Ledger written only through `Ledger.post`.

**Never:**
- No bid placement, no edition price refresh or `average_after_sale` (story 3, which adds its step inside the settlement), no bid history rows, outbid notices, feed entry, forfeit or `DropPresenceJob` (epic 40), no screen change, no migration, no `db/schema.rb` change.
- No second path that moves a copy or a PiCoin outside `CloseAuction`'s transaction; no `Ledger.post` in the settlement step; no rescue that hides a failed listing from the error tracker.

**Decisions (settled by Claude, no checkpoint in this run; the author may revisit):**
- The shared settlement is the mixin `AuctionSettlement` (like `MoveHoldings`), not an operation; story 4's buy-now includes it and passes `held: buy_now`.
- A non-sold close clears `leader_id` and `leader_maximum` (the hold is gone); a sold close keeps both as the record of the winner and the maximum.
- A withdrawn listing also releases the seller's `reserved`, so no reservation outlives its listing.
- Zero-amount entries (no surplus, zero commission) are not written.
- The commission reads the listing's own settings version through `settings_id`, not the current one.
- The closed-meanwhile answer is `Failure(:listing_not_closable)`, ignored by the job like `ExpireTrade::CLOSED_MEANWHILE`; unknown listing or other seller is `Failure(:listing_not_found)`.
- `AuctionSold` carries `outbid_player_id` and `outbid_released`, nil and 0 at close (nobody is outbid by a close) and filled by story 4's buy-now.
- Balance notices: `AuctionSold` seller, winner and any outbid player; `AuctionUnsold` the seller; `ListingWithdrawn` the seller and the leader when present.
- The settlement step publishes the tier events and `CloseAuction` publishes the one primary event after them; no schema change is needed.
- `OldestDueListing` answers whole seconds or nil; the 5-minute threshold lives in the job.
- Leader state in tests comes from `test/support/market_auctions.rb`, a new file, to stay clear of other stories' support files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Worked example | Settings commission 1000 bp, start 20,000, leader holds maximum 40,000, price 31,500, due | `sold` at 31,500; winner purchase -31,500 committed and release 8,500 (committed to available); seller sale +31,500 and commission -3,150 (net 28,350); copy moves; one `AuctionSold` | No error expected |
| No leader | Due, `leader_id` null | `unsold`, seller's `reserved` -1, `AuctionUnsold`; no ledger entry | No error expected |
| Removed seller, leader | Seller banned or deleted, leader holds a maximum | `withdrawn`, leader's maximum released, leader cleared, reservation released, `ListingWithdrawn` with leader and amount | No error expected |
| Removed leader | Leader banned or deleted, seller active | maximum released, leader cleared, `unsold`, reservation released, `AuctionUnsold` | No error expected |
| Both removed | Seller and leader removed | Seller wins precedence: `withdrawn`, maximum released | No error expected |
| Second run | Listing already closed, or a second job run | Nothing changes: no entry, no event, no copy moved | `Failure(:listing_not_closable)`, job ignores it |
| Not due yet | `ends_at` in the future, or a bid extended it since the unlocked read | Nothing changes | `Failure(:listing_not_closable)` |
| Leader changed meanwhile | Another leader after the unlocked read | Nothing changes, the next run retries | `Failure(:listing_not_closable)` |
| Deadlock | `ActiveRecord::Deadlocked` | Rolled back | `Failure(:market_busy)`; the job reports it and moves on |
| One listing raises | A listing's close raises | The others in the batch still close | Reported with the listing id, run goes on |
| Stuck close | Oldest due open listing older than 5 minutes | `CheckMarketHealthJob` reports to the error tracker | Report only, never raises |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/list_card.rb` -- sibling operation: shape to copy (lock_bank, `current_settings`, `reserve`, publish on `stream_name(seller)`, `rescue Deadlocked` to `:market_busy`); `reserve` is mirrored by the release here.
- `app/domains/game/app/operations/game/accept_trade.rb`, `move_holdings.rb`, `trade_steps.rb` -- the settlement's pattern: `receive_allocations`, `move`, `ShowcaseEntry.remove_unheld`, `SetTier.record(..., reached_by: "trade")`, `publish_tiers`; `MoveHoldings#move` is the extracted move.
- `app/domains/game/app/operations/game/expire_trade.rb`, `close_trade.rb`, `jobs/game/expire_trades_job.rb` -- model for `require_account`, the `CLOSED_MEANWHILE` failure constant and a job that reports and moves on.
- `app/domains/game/app/operations/game/operation.rb` -- `require_account`, `lock_bank`, `publish_tiers`, `stream_name`.
- `app/domains/game/app/models/game/trade_locks.rb`, `bank_lock.rb` -- `TradeLocks.players` (ascending bank locks), `TradeLocks.holdings`.
- `app/domains/game/app/models/game/market/ledger.rb`, `ledger_entry.rb` -- `Ledger::Entry` and the single `post`; kinds `purchase`, `release`, `sale`, `commission` exist; the unique settlement index (listing, player, kind) already refuses a second settlement.
- `app/domains/game/app/models/game/market/listing.rb`, `auction_math.rb`, `settings.rb` -- listing model (add `due` scope and `leader`/`card_season` reads), `AuctionMath.commission(price, basis_points)`, version values read through the listing's `settings_id`.
- `app/domains/game/app/handlers/game/handlers/goals_reached.rb`, `achievements.rb`, `trade_accepted.rb` -- subscriptions; the weekly contribution is fed only by `trade_accepted.rb`, so `AuctionSold` stays out of it by not being subscribed there.
- `config/initializers/event_store.rb` -- subscribes handlers by their `EVENTS` constants.
- `app/models/player_stream.rb` -- `BALANCE_EVENTS` and `balance_notice`, extended by this story.
- `app/domains/game/app/jobs/game/reconcile_wallets_job.rb` -- model for a job reporting through `Rails.error.report(..., handled: true, context:)`.
- `config/recurring.yml` -- anchors plus `development` and `production` blocks.
- `db/migrate/20261110120001_add_open_ends_at_index_to_game_market_listings.rb` -- index serving the due scan and the oldest-due read; no migration needed.
- `test/support/market.rb`, `market_listings.rb`, `holdings.rb`, `test/domains/game/market/list_card_test.rb`, `test/domains/game/reconcile_wallets_job_test.rb` -- test arrangement to reuse (`open_market!`, `listing!`, `hold`, `Mint.credit`); `players` fixtures `player`, `moderator`, `administrator`, `banned`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/listing.rb` -- add `belongs_to :leader` (optional), `scope :due, ->(now) { open_now.where(ends_at: ..now) }` -- one definition of due shared by the job, the health query and the recheck
- [ ] `app/domains/game/app/events/game/market/auction_sold.rb` -- new event class -- data: `listing_id`, `seller_id`, `winner_id`, `card_season_id`, `final_price`, `surplus`, `outbid_player_id`, `outbid_released`
- [ ] `app/domains/game/app/events/game/market/auction_unsold.rb` -- new event class -- data: `listing_id`, `seller_id`
- [ ] `app/domains/game/app/events/game/market/listing_withdrawn.rb` -- new event class -- data: `listing_id`, `seller_id`, `leader_id`, `released` (0 and nil leader when none)
- [ ] `app/domains/game/app/operations/game/market/auction_settlement.rb` -- new mixin (includes `MoveHoldings`): `settle_sale(listing:, winner_id:, held:, final_price:, now:)` doing the season read, winner allocation, holdings locks (ascending player), one-copy move with `reserved`, tiers (`reached_by: "trade"`) and their events, showcase cleanup, listing `sold` update, returning entries (`purchase`, surplus `release`, `sale`, `commission`; zero amounts skipped) and a `sold_event` builder story 4 reuses -- the one settlement both close and buy-now call, posting nothing
- [ ] `app/domains/game/app/operations/game/market/close_auction.rb` -- new operation `CloseAuction#call(player:, listing_id:)`: unlocked read, `TradeLocks.players`, listing lock and recheck, removal read, branch (withdrawn, unsold, removed-leader unsold, sold), release of the reservation on non-sold ends, one `Ledger.post`, one event, `CLOSED_MEANWHILE` constant, `rescue Deadlocked` to `:market_busy` -- the exactly-once close
- [ ] `app/domains/game/app/jobs/game/close_due_auctions_job.rb` -- new job on queue default: `Listing.due(now)` in batches, sellers loaded once per batch, `CloseAuction` per listing, `value!` unless `CLOSED_MEANWHILE`, `rescue StandardError` reports with the listing id and goes on -- R8
- [ ] `app/domains/game/app/queries/game/market/oldest_due_listing.rb` -- new query `call(now: Time.current)`: whole seconds since the oldest due open listing's `ends_at`, nil when none -- the back-office's figure (epic 41 shows it)
- [ ] `app/domains/game/app/jobs/game/check_market_health_job.rb` -- new job: reports `StaleClose` through `Rails.error.report(handled: true, context: { age_seconds: })` when the age is over 5 minutes, otherwise nothing -- R12
- [ ] `app/domains/game/app/handlers/game/handlers/goals_reached.rb` -- map events to their player keys (`PackOpened` player, `TradeAccepted` proposer and recipient, `CustomSetEdited` player, `AuctionSold` winner) and list `AuctionSold` in `EVENTS`
- [ ] `app/domains/game/app/handlers/game/handlers/achievements.rb` -- add `Game::Market::AuctionSold => [ :winner_id ]`
- [ ] `app/models/player_stream.rb` -- add the three events to `BALANCE_EVENTS`; notices: `AuctionSold` seller, winner and the outbid player when present; `AuctionUnsold` seller; `ListingWithdrawn` seller and leader when present -- balance chip follows every wallet that moved
- [ ] `config/recurring.yml` -- anchors `close_due_auctions` (`every 10 seconds`) and `check_market_health` (`every 5 minutes`), queue default, in both `development` and `production`
- [ ] `config/locales/en.yml` and `config/locales/fr.yml` -- `errors.game.listing_not_found`, `listing_not_closable` (by hand, beside `market_busy`)
- [ ] `test/support/market_auctions.rb` -- new arrangement: `fund!(player, amount)` and `lead!(listing, player, maximum, price:)` posting a `hold` through `Ledger.post` and setting the leader columns -- leader state until story 4's bidding exists
- [ ] `test/domains/game/market/close_auction_test.rb` -- operation tests of the I/O matrix: worked example, no leader, removed seller, removed leader (banned and deleted), second run, not due, leader changed, allocation received, tiers recorded with `reached_by: "trade"`, showcase entry removed, ledger reconciles through `ReconcileWallets`, entries zero-skipping, event data, no bank deadlock
- [ ] `test/domains/game/market/close_auction_events_test.rb` -- `GoalsReached` and `Achievements` hear `AuctionSold` for the winner only, `WeeklyContribution` and the weekly total do not move; balance notices enqueued after commit through `PlayerStream`, none before
- [ ] `test/domains/game/close_due_auctions_job_test.rb` -- one failing listing does not stop the others (error reported with the listing id); a second job run changes nothing; an undue and a closed listing are left alone
- [ ] `test/domains/game/check_market_health_job_test.rb` and `test/domains/game/market/oldest_due_listing_test.rb` -- no report at 5 minutes or under, a report over it, age value and nil
- [ ] `test/models/player_stream_test.rb` -- notices for the three events
- [ ] `test/domains/game/market/ledger_write_guard_test.rb` -- keep green: the settlement step must not reference the ledger's write methods

**Acceptance Criteria:**
- Given the worked example's state, when `CloseAuction` runs, then the seller's wallet gains 28,350 net, the winner's available returns 8,500 and committed holds nothing of that listing, the destroyed total grows by 3,150 and `ReconcileWallets` reports no difference.
- Given a listing closed once, when the close runs again by the operation or by two job runs, then no entry, event, copy or reservation changes.
- Given a due listing with a leader, when it settles, then the seller's holding drops by one with its `reserved`, the winner's rises by one, the winner's pending allocation is received before the credit and set tiers carry `reached_by: "trade"`.
- Given a close inside a transaction, when it commits, then the balance notices are enqueued after commit and none exists if it rolls back.
- Given one listing that raises in the job, when the job runs, then the other due listings close and the error is reported once.
- Given the oldest due open listing is 6 minutes old, when `CheckMarketHealthJob` runs, then one error is reported; at 4 minutes none.

## Implementation Notes

## Plan Change Log

- 2026-11-10 review: code matched the plan (lock order, single Ledger.post, one event, locale keys, handlers, recurring jobs); no code defect found. Added the missing test that the winner's allocation is received. Static checks ran: ruby -c, planning-id and file-size scripts pass; rubocop and packwerk could not run in the worktree (bundle gems missing).

## Review Triage Log

## Design Notes

- The settlement is a mixin, not an operation: it never commits or posts, so it can sit inside `CloseAuction` now and `PlaceBid`'s buy-now branch later, each making its own single `Ledger.post`. At buy-now the caller passes `held: buy_now`, so the surplus is zero by the same arithmetic as the close.
- Surplus is `held - final_price`, with `held` the leader's maximum at close; entries net per wallet inside `Ledger.post`, so the seller's `sale` and `commission` reach one balance change.

```ruby
entries = [ Entry.new(player_id: winner_id, kind: :purchase, committed_delta: -price, listing_id:, settings_id:),
  Entry.new(player_id: seller_id, kind: :sale, available_delta: price, ...),
  Entry.new(player_id: seller_id, kind: :commission, available_delta: -AuctionMath.commission(price, bp), ...) ]
entries << Entry.new(player_id: winner_id, kind: :release, available_delta: surplus, committed_delta: -surplus, ...) if surplus.positive?
```

- Story 3 adds its edition price refresh as one more step of `settle_sale`, before the entries are returned.

## Verification

**Commands:**
- `ruby -c` and `bundle exec rubocop` on each touched Ruby file -- expected: no offence
- `bundle exec packwerk check` -- expected: no violation
- `script/check_planning_references` and `script/check_file_sizes` -- expected: pass
- `bin/rails test test/domains/game/market test/domains/game/close_due_auctions_job_test.rb test/domains/game/check_market_health_job_test.rb test/models/player_stream_test.rb` -- expected: green (run once at the end of the market build, not by the build agent)
- `bin/rails zeitwerk:check` -- expected: pass
