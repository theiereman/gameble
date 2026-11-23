---
title: "A removed player's orders, wanted rows and slots leave with them"
type: 'feature'
ticket: '20'
created: '2026-11-23'
status: 'built'
baseline_revision: 'ca6b31826d4b0b587bdf0832c56156932256dcc9'
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

**Problem:** A banned or deleted player's open buy orders stay open: their money stays held, a deleted owner's balance is never forfeited, `ExpireDueOrdersJob` reports a deleted owner's due order every minute, the deleted owner's `order` wanted rows survive (`ReleasePlayer` refreshes before `deleted_at` is set), and `OrderWithdrawn` has no publisher. The export, the privacy pages and the Delete dialog do not name orders, sales to orders, Archive purchases or bought slots (epic R22).

**Approach:** `DropPresenceJob` gains an order step that runs a new `Game::Market::WithdrawOrder` once per open order of a removed owner, before the forfeit; the operation withdraws, releases, refreshes the owner's wanted rows and publishes `OrderWithdrawn`. The market export gains orders, sales to orders, Archive purchases and bought slots; the legal page and the Delete dialog name them in both locales. `ReleasePlayer` already deletes wanted (through `RefreshWanted`), tied-account and capacity rows: keep it, and test it.

## Boundaries & Constraints

**Always:**
- `WithdrawOrder.call(player:, order_id:)`: `require_account` (a removed owner must pass); in one transaction: `TradeLocks.players(player.id)` (never `lock_bank`, which refuses a deleted owner), `Order.lock.find_by(id:, player_id:)`, refuse `NOT_WITHDRAWABLE = Failure(:order_not_withdrawable)` unless the order is `open` (due or not) and the owner is removed in the database (`Accounts::Player.removed.exists?`); `update!(status: "withdrawn")`; post one `release` (`available_delta: price`, `committed_delta: -price`, `order_id`, the order's `settings_id`) as `CancelOrder` does; `RefreshWanted.call(player)` (the `WantedRefresh` handler skips removed players, so the operation refreshes itself; a removed player's refresh deletes every row); publish `OrderWithdrawn.about(order)` on the owner's stream; `rescue ActiveRecord::Deadlocked` → `Failure(:market_busy)`. No notice written (the existing `OrderNotices` handler deletes the order's `listed_above_order`).
- `RemovedPresence.orders`: open orders (any `expires_at`) whose owner is `Accounts::Player.removed`, plucked as `[id, player_id]`.
- `DropPresenceJob#perform`: sellers, leaders, then orders, then the forfeit; each order its own call, a failure other than `NOT_WITHDRAWABLE` reported with `context: { order_id: }` without stopping the others.
- `ExpireDueOrdersJob` skips orders whose owner is deleted (`deleted_at` set): the withdrawal handles them. A banned owner's due order still expires.
- `ForfeitBalance` keeps refusing while money is committed (an open order holds its price as committed), so it waits for the withdrawal; no code change unless a test shows otherwise.
- Export (`Game::Market::ExportOf` → `PlayerExport`): `buyOrders` (the player's orders: `token`, `game` = the card's `slug`, `status`, `price`, `placedAt`, `expiresAt`, `servedCard` = `card(served_card_season_id)` or nil, `servedAt`); `salesToOrders` (served orders where the player is `seller_id`: `card`, `price`, `soldAt`; never the buyer, the order's token or the buyer's id); `archivePurchases` (the player's `game_market_archive_withdrawals`: `card`, `price`, `boughtAt`); `boughtSlots` (`game_capacity_slots`: `kind`, `bought`); `picoinEntries` gain `order` (the order's token, nil otherwise). Every card_season id the new rows name joins `ExportOf::Result#card_season_ids` so `card()` resolves it. Times through `time()`.
- Copy, both locales, French with U+202F before `:`/`;` as the file does: `accounts.dialog.market_html` ends "…once your running listings are withdrawn, your bids released and your open buy orders withdrawn." / "…une fois vos annonces en cours retirées, vos offres libérées et vos ordres d'achat en cours retirés."; `accounts.dialog.kept`'s market history and the matching legal lines name buy orders, sales to orders and Archive purchases ("listings, bids, buy orders and sales to orders, entrusted cards, Archive purchases, notices and PiCoin movements…" / "annonces, enchères, ordres d'achat et ventes à des ordres, cartes confiées, achats aux Archives, avis et mouvements de PiCoins…"); `pages.legal.privacy.stored.market`, `retention.market`, `market_deletion` (open buy orders withdrawn, a banned owner's PiCoins returned, a deleted owner's destroyed with the balance) and `rights.access` (the export adds buy orders, sales to orders, Archive purchases and bought slots); `pages.legal.updated` becomes 23 November 2026 / 23 novembre 2026.

**Never:**
- No migration; no new index (the export's `seller_id` read is a rare per-player job).
- No write of `game_market_wanted` outside `RefreshWanted`; no publish from a handler; no `lock_bank` in `WithdrawOrder`; no notice or push for a withdrawn order.
- No change to `ReleasePlayer`'s deletions (already built) beyond what a failing test proves necessary.
- No planning ids in code or tests; no model named in a test class body.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Banned owner | B has an open order (price 900, a `listed_above_order` notice, an `order` wanted row); B is banned; job runs | Order `withdrawn`; one `release`; B's wallet available +900, committed 0; notice gone; B's wanted rows gone; one `OrderWithdrawn`; B's wallet kept | No error expected |
| Deleted owner | D (funded) has an open order; `DeletePlayer` then job runs | Order `withdrawn`, release then `forfeit` of the whole balance in the same pass; wallet 0/0; reconciliation balanced; D's wanted, tied and capacity rows gone | No error expected |
| Due order of a deleted owner | D's open order past `expires_at` | `ExpireDueOrdersJob` skips it, reports nothing; `DropPresenceJob` withdraws it | No error expected |
| Present owner | An order of a player in good standing | Untouched by the job | `NOT_WITHDRAWABLE` if called directly |
| Second run | Job run again | No new ledger entry, no error | `NOT_WITHDRAWABLE` skipped |
| Ended order | Served/expired/cancelled order of a removed owner | Untouched | `NOT_WITHDRAWABLE` |
| One order raises | Two orders, the first raises | The second is withdrawn; the error reported with its `order_id` | Reported, loop goes on |
| Eligibility | A removed owner's order on a wanted card | `EligibleOrders` skips it (already true; assert) | — |
| Export | Player with an order, a sale to another's order, an Archive purchase, a bought slot | `buyOrders`, `salesToOrders`, `archivePurchases`, `boughtSlots` filled; no buyer identity in `salesToOrders`; entries name the order token | — |

</intent-contract>

## Code Map

- Worktree: work only in `/home/teyermann/projets/gameble-mv-m` (branch `mv/m`); start every shell command with `cd /home/teyermann/projets/gameble-mv-m &&`; call git only as `/usr/bin/git`; never commit, stage or push (the orchestrating session commits). Never touch another `/home/teyermann/projets/gameble*` directory.
- `app/domains/game/app/operations/game/market/cancel_order.rb`, `expire_order.rb` -- shape to mirror (ledger entry, publish, deadlock rescue). `withdraw_listing.rb` -- the removed-owner pattern (`require_account`, `TradeLocks.players`, `Accounts::Player.removed.exists?`, `NOT_WITHDRAWABLE` constant). `operation.rb` -- `require_account`, `lock_bank` (refuses deleted: do not use).
- `app/domains/game/app/models/game/market/refresh_wanted.rb` -- requires the bank lock held; deletes then returns for `player.removed?`. `models/game/trade_locks.rb` -- `players(*ids)` takes the bank locks.
- `app/domains/game/app/events/game/market/order_withdrawn.rb` -- `about(order)`, already heard by `handlers/.../wanted_refresh.rb` (skips removed players), `order_notices.rb` (deletes the `listed_above_order`), `app/models/player_stream.rb` (`BALANCE_EVENTS`). No subscription change.
- `app/domains/game/app/queries/game/market/removed_presence.rb`, `app/domains/game/app/jobs/game/market/drop_presence_job.rb` (`drop` handles listings with `listing_id:`; add a sibling for orders with `order_id:` rather than generalising), `jobs/game/market/expire_due_orders_job.rb`, `operations/game/market/forfeit_balance.rb` (`settled` refuses committed money), `queries/game/market/eligible_orders.rb` (already skips removed owners).
- `app/domains/game/app/operations/game/release_player.rb`, `app/domains/accounts/app/operations/accounts/delete_player.rb` (publishes `PlayerDeleted` before setting `deleted_at`, in one transaction) -- read only.
- Export: `app/domains/game/app/queries/game/market/export_of.rb` (`Result` rows and `card_season_ids`), `app/domains/game/app/queries/game/export_of.rb` (carries `market`; 208 lines, leave it), `app/models/player_export.rb` (192 lines; add the four sections after `bids:`, and `order:` in `picoin_entry`). Tables: `game_market_orders` (`token, player_id, card_id, price, status, expires_at, seller_id, served_card_season_id, served_at, created_at`), `game_market_archive_withdrawals` (`player_id, card_season_id, price, created_at`; model `Game::Market::ArchiveWithdrawal` — check its name under `models/game/market/`), `game_capacity_slots` (`Game::CapacitySlot`: `player_id, kind, bought`), `catalog_cards.slug` (`Catalog::Card`).
- Copy: `config/locales/{en,fr}.yml` keys `accounts.dialog.{market_html,kept}`, `pages.legal.{updated,privacy.stored.market,privacy.retention.market,privacy.market_deletion,privacy.rights.access}`; view `app/views/accounts/_dialog.html.erb` and `app/views/pages/legal.html.erb` unchanged.
- Tests to update or mirror: `test/domains/game/market/drop_presence_job_test.rb`, `forfeit_balance_test.rb`, `withdraw_listing_test.rb` (shape for a new `withdraw_order_test.rb`), `expire_due_orders_job_test.rb` (find its name), `eligible_orders_test.rb`, `wanted_refresh_test.rb`, `test/domains/game/release_player_market_test.rb`, `test/domains/accounts/delete_player_test.rb`, `test/domains/game/market/export_of_test.rb`, `test/models/player_export_market_test.rb` (key lists asserted), `test/controllers/settings_delete_dialog_test.rb`, `test/controllers/accounts_controller_test.rb` (table → copy map: update the market history phrase in both locales), `test/controllers/pages_controller_test.rb` (`COPY`, the `.legal__access` assertion, every "10 novembre 2026"/"10 November 2026"), `test/system/market_removed_players_test.rb`. Supports: `test/support/market_orders.rb` (`order!`, `buyer!`), `test/support/market.rb` (`open_market!`, `fund!`), `holdings.rb`. Wanted rows come from `Game::Market::RefreshWantedJob` after commit: perform enqueued jobs (`include ActiveJob::TestHelper`) before asserting rows set up through events.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/operations/game/market/withdraw_order.rb` (new) -- the operation of Always.
- [x] `app/domains/game/app/queries/game/market/removed_presence.rb`, `app/domains/game/app/jobs/game/market/drop_presence_job.rb` -- the order finder and step, before the forfeit.
- [x] `app/domains/game/app/jobs/game/market/expire_due_orders_job.rb` -- skip deleted owners.
- [x] `app/domains/game/app/queries/game/market/export_of.rb`, `app/models/player_export.rb` -- the four sections and the entries' order token.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- the copy of Always.
- [x] Tests -- `withdraw_order_test.rb` (banned, deleted, due, present owner refused, ended order refused, second call, notice deleted, wanted rows gone, event published, ledger release once); `drop_presence_job_test.rb` (orders withdrawn, deleted owner forfeited in the same pass with reconciliation balanced, one order raising reported with `order_id`, second run no-op); `expire_due_orders_job_test.rb` (deleted owner skipped without report); `eligible_orders_test.rb` already covers removed owners (leave or extend); `release_player_market_test.rb` or `delete_player_test.rb` (after `DeletePlayer` then the job: no wanted, tied-account or capacity row names the player; orders, withdrawals and ledger entries keep the player id); `export_of_test.rb` and `player_export_market_test.rb` (the four sections, keys, no buyer identity in a sale to an order); dialog, accounts and pages controller tests updated; one system test in `test/system/market_removed_players_test.rb`: a player with an open order opens the Delete dialog and reads "your open buy orders withdrawn".

**Acceptance Criteria:**
- Given a player with an open buy order, when they open "Delete my account" in the settings, then the market line says their open buy orders are withdrawn.
- Given that player deletes the account, when `DropPresenceJob` runs, then the order is `withdrawn`, the balance is forfeited to zero and no wanted row names them.

## Implementation Notes

- `picoinEntries[].order` names only the player's own orders: a seller's `sale` entry for serving another player's order carries that order's id, and exporting its token would contradict "never the order's token" in `salesToOrders`; it is nil there.
- `WithdrawOrder` refreshes wanted rows with the owner loaded through `Accounts::Player.removed`, so a stale in-memory player cannot rewrite rows.
- The order's card slug comes from `Catalog::PublishedCardIds.slugs`.

## Plan Change Log

## Review Triage Log

## Design Notes

- `ReleasePlayer` runs inside `DeletePlayer` before `deleted_at` is set, so its `RefreshWanted` writes the still-open orders' rows; reads already skip a deleted player (same transaction), and `WithdrawOrder`'s own refresh deletes the rows within a minute. That keeps `RefreshWanted` the only writer.
- The ticket's `unknown` (bought slots die with the account) is the architecture's adopted rule (AD-46 lists it as an assumption the author has not overturned); `ReleasePlayer` already deletes capacity rows and the copy says "your bought slots" are erased. Followed, not reopened.
- `ExpireDueOrdersJob` skipping deleted owners stops the every-minute report; expiring into a deleted wallet would race the forfeit.

## Verification

**Commands:**
- `cd /home/teyermann/projets/gameble-mv-m && export DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_m PARALLEL_WORKERS=4 && (RAILS_ENV=test bin/rails db:create db:schema:load || true) && bin/rails test <the touched and new non-system test files>` -- expected: green (create the database first if missing).
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing`, `bundle exec rubocop` on touched Ruby files -- expected: pass.
- Do not run system tests or the full suite.

## Auto Run Result

- **Summary:** `Game::Market::WithdrawOrder` withdraws a removed owner's open order (due or not) under the owner's bank lock (`TradeLocks.players`, not `lock_bank`), posts its `release`, refreshes the owner's wanted rows (deleting them all) and publishes `OrderWithdrawn`, whose existing handler deletes the `listed_above_order` notice. `DropPresenceJob` withdraws such orders after the listings and leads and before the forfeit, so a deleted owner's balance is forfeited in the same pass; `ExpireDueOrdersJob` skips deleted owners. The export gains `buyOrders`, `salesToOrders` (no buyer, no order token), `archivePurchases`, `boughtSlots` and the order token on the owner's PiCoin entries; the Delete dialog and the legal page name orders, sales to orders, Archive purchases and bought slots in both locales (legal page dated 23 November 2026). `ReleasePlayer` already deleted wanted, tied-account and capacity rows; a test now proves it end to end.
- **Files:** `withdraw_order.rb` (new), `removed_presence.rb`, `drop_presence_job.rb`, `expire_due_orders_job.rb`, `market/export_of.rb`, `player_export.rb`, `en.yml`, `fr.yml`; tests `withdraw_order_test.rb` (new), `drop_presence_job_test.rb`, `expire_due_orders_job_test.rb`, `export_of_test.rb`, `release_player_market_test.rb`, `player_export_market_test.rb`, `player_export_test.rb`, `settings_delete_dialog_test.rb`, `accounts_controller_test.rb`, `pages_controller_test.rb`, `test/system/market_removed_players_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** 16 targeted test files, 191 runs, 0 failures (`gameble_test_m`, 4 workers), rerun by the orchestrating session; `check_planning_references`, `check_file_sizes`, `packwerk check`, `zeitwerk:check`, `i18n-tasks missing`, rubocop on the 17 touched Ruby files pass. No migration. The system test is written, not run.
- **Residual risks:** the system test is unrun; a deleted owner's `order` wanted rows live until the next `DropPresenceJob` (at most a minute; reads skip them meanwhile); `salesToOrders` reads orders by `seller_id` without an index (export only); the new legal and dialog copy awaits the author's approval.
