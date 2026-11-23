---
title: 'Wanted cards are one table every change refreshes'
type: 'feature'
ticket: '6'
created: '2026-11-23'
status: 'built'
baseline_revision: 'aceca1111d28e6145851d4601812da721b63c03b'
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

**Problem:** "Wanted" is recomputed per read from goals (`WantingPlayers`, `GoalNeeds` in `MarketsController`), ignores buy orders, and cannot give per-card counts to sellers; every later market-volume screen needs one wanted table and one event wiring.

**Approach:** Add `game_market_wanted` (one row per player, card and reason), written only by `Game::Market::RefreshWanted.call(player)` under the player's bank lock, run by one Game handler after `GoalsReached` for every event that changes goals, custom sets, holdings or orders; rebuild it per player at unban, for all at season publish and in a data migration; point `WantingPlayers`, the new `WantedCounts` and the buyer's VOULUE tag/chip at it.

## Boundaries & Constraints

**Always:** strong_migrations; check expressions as regex/equalities so `db/schema.rb` round-trips; regenerate `db/schema.rb` from migrations on PG18 (AGENTS.md command, `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_mv_schema`); `RefreshWanted` publishes nothing and never takes a lock; handlers never publish; jobs enqueued after commit (already the ActiveJob default here); both locales; no planning ids; files ≤ 400 lines.

**Never:** no Vos cartes voulues panel, DEMANDÉE badge, VOULUES PAR D'AUTRES chip or card-detail count (story 13 reads `WantedCounts`); no publisher for `ArchivePurchased`, `SlotBought`, `OrderExpired`, `OrderWithdrawn` (later stories) — only their subscriptions; no move of the refresh into a job (entry 22); no change to bell or push copy ("qui manque à vos objectifs" lines stay); no clearing of rows on ban.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Goal rows | goal on a set with 2 missing games | 2 `goal` rows, `rarities` null | none |
| Order row | open order reaching common+uncommon | 1 `order` row, `rarities` `{1,2}` | none |
| Goal and order on one game | both | 2 rows; counts and `WantingPlayers` count the player once | none |
| Refresh without lock | `RefreshWanted.call(player)` outside the bank lock | nothing written | raises |
| Removed player | banned or deleted player refreshed | all their rows deleted, none written | none |
| Banned with rows left | rows exist, player then banned | `WantingPlayers` and `WantedCounts` skip them | none |
| Unban | `UnbanPlayer` commits | `RebuildWantedJob` enqueued; run, rows equal a fresh refresh | none |
| Order rarity | order reaching only common; rare edition | not in `WantingPlayers(rare)` nor in `WantedCounts` at rare; in common | none |
| Viewer | `WantedCounts(ids, except: viewer)` | viewer never counted | none |
| Other writer | a file in app/lib writes the table | writer guard test fails | test |

</intent-contract>

## Code Map

- Every path is relative to `/home/teyermann/projets/gameble-market`, a git worktree: work only there (never in `/home/teyermann/projets/gameble`), start every shell command with `cd /home/teyermann/projets/gameble-market &&`, call git as `/usr/bin/git`, never commit; run only targeted tests with the test `DATABASE_URL` of Verification (create it with `RAILS_ENV=test bin/rails db:create db:schema:load` once the schema is regenerated), never the full suite or system tests; never run the benchmark (the orchestrator runs it).
- `db/migrate/20261120183000_create_game_market_tied_accounts.rb` -- create-table pattern (inline unique index, inline check); `20261120160003_grant_capacity_slots_already_used.rb` -- data migration shape (`def down; end`).
- `app/domains/game/app/models/game/bank_lock.rb` -- `acquire` key: `((id + 2**31) % 2**32) - 2**31`, namespace `0x47414D45`; add `held?(player_id)` reading `pg_locks` (`locktype = 'advisory'`, `pid = pg_backend_pid()`, `granted`, `classid` = namespace, `objid` = key mod 2**32 as oid, `objsubid = 2`).
- `app/domains/game/app/models/game/market/ledger.rb` -- precedent of a sole-writer module in models; `test/domains/game/market/ledger_write_guard_test.rb` -- guard test to mirror.
- `app/domains/game/app/queries/game/goal_needs.rb` -- `GoalNeeds.call(player).flat_map(&:missing_card_ids)` (catalog card ids).
- `app/domains/game/app/models/game/market/order.rb` -- `open_at(now)`; `queries/game/market/order_rarities.rb` -- `OrderRarities.call(ids)` → `{ id => [:common, ...] }` built only from `Order.reaching`; `Catalog::Rarity::TIERS` `{1=>:common..5=>:legendary}`; `CardSeason#rarity` is an enum name string.
- `app/domains/game/app/queries/game/market/wanting_players.rb` -- rewrite to read the table; only caller `handlers/game/market/handlers/wanted_notices.rb`.
- `app/domains/game/app/handlers/game/handlers/goals_reached.rb`, `achievements.rb` -- maps of event → data keys; `achievements_test.rb:756` "every trigger" counts 26 jobs from one data hash.
- Event data keys: `PackOpened` player_id; `TradeAccepted` proposer_id, recipient_id; `AuctionSold` seller_id, winner_id; `OrderServed` buyer_id, seller_id; `WantedChoicesApplied` seller_id, sales[].buyer_id; `CardsEntrusted`, `ArchivePurchased`, `GoalAdded`, `GoalRemoved`, `CustomSetEdited`, `CustomSetDeleted`, `Order{Placed,Cancelled,Expired,Withdrawn}` player_id; `SlotBought` player_id, goal_id (nil without a goal); `Accounts::PlayerUnbanned` player_id. Every current publisher already holds each named player's bank lock (`lock_bank`, `TradeLocks.players`).
- `config/initializers/event_store.rb` -- subscriptions run in order; `GoalsReached` line ~35.
- `app/domains/game/app/handlers/game/handlers/season_published.rb` -- runs `Goal.drop_unpublished` then enqueues jobs; `jobs/game/heal_banks_job.rb` -- per-player loop with `Accounts::PlayersInBatches` (skips banned and deleted), error report per player.
- `app/domains/game/app/operations/game/operation.rb` -- `Game::Operation` (`call(player:)` required), `require_account`, `lock_bank` (Failure `:player_required` for deleted).
- `app/domains/game/app/operations/game/release_player.rb` -- deletion clear list.
- `app/controllers/markets_controller.rb` `wanted_card_ids`, `load_wanted_count`; `app/models/listing_marks.rb`; `app/helpers/market_helper.rb` `listing_ownership_state`; locales `markets.tile.ownership.wanted_spoken` (fr ~2967 "manque à vos objectifs", en ~3934 "missing from your goals").
- Tests to adjust: `test/controllers/market_wanted_cards_test.rb` (aria-label suffix), `test/system/market_filters_test.rb:95` (suffix, do not run), `test/domains/game/market/wanted_notices_test.rb` (the holder holds after aiming: rebuild their rows), `test/domains/game/achievements_test.rb`, `test/controllers/accounts_controller_test.rb` `ERASED_OR_CANCELLED` (FK tables list). Helpers: `test/support/{holdings,game_sets,game_packs,game_trades,custom_sets,market,market_orders,market_listings}.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261123100000_create_game_market_wanted.rb` -- `player` (FK accounts_players), `card` (FK catalog_cards, own index), `reason` string, `rarities` smallint array; inline unique `(player_id, card_id, reason)`; checks `reason ~ '^(goal|order)$'` and `(reason = 'goal') = (rarities IS NULL)`; no timestamps.
- [x] `db/migrate/20261123100001_rebuild_game_market_wanted.rb` -- `disable_ddl_transaction!`, `up` runs `Game::Market::RebuildAllWantedJob.perform_now`, empty `down`.
- [x] `db/schema.rb` -- regenerated.
- [x] `app/domains/game/app/models/game/market/wanted.rb` -- model, `REASONS`, scopes `in_play` (owner not removed) and `counting_at(rarity_name)` (`reason = 'goal' OR tier = ANY(rarities)`; nil rarity → goal rows only).
- [x] `app/domains/game/app/models/game/bank_lock.rb` -- `held?`.
- [x] `app/domains/game/app/models/game/market/refresh_wanted.rb` -- `RefreshWanted.call(player, now: Time.current)`: raise unless `BankLock.held?`; delete the player's rows; unless `player.removed?`, `insert_all` goal rows (missing games) and order rows (open orders, tiers from `OrderRarities`, an order reaching nothing skipped) — `insert_all` is ON CONFLICT DO NOTHING.
- [x] `app/domains/game/app/operations/game/market/rebuild_wanted.rb` -- `Game::Operation`: `require_account`, transaction, `lock_bank`, `RefreshWanted.call`; no event.
- [x] `app/domains/game/app/jobs/game/market/rebuild_wanted_job.rb` (player id; missing or deleted player ignored) and `rebuild_all_wanted_job.rb` (queue default; `PlayersInBatches`, one `RebuildWanted` per player, `:player_required` ignored, other errors reported per player as `HealBanksJob`).
- [x] `app/domains/game/app/handlers/game/handlers/named_players.rb` -- `NamedPlayers.of(event, map)`: map value is data keys or a callable over the data; compact, uniq.
- [x] `app/domains/game/app/events/game/market/wanted_choices_applied.rb` -- `self.buyer_ids(data)` and `self.player_ids(data)` (seller then buyers).
- [x] `goals_reached.rb` -- add `OrderServed` [:buyer_id], `WantedChoicesApplied` buyers, `ArchivePurchased` [:player_id]; use `NamedPlayers`.
- [x] `achievements.rb` -- add `OrderServed` [:buyer_id, :seller_id], `WantedChoicesApplied` seller and buyers, `ArchivePurchased` [:player_id]; use `NamedPlayers`.
- [x] `app/domains/game/app/handlers/game/market/handlers/wanted_refresh.rb` -- `PLAYERS` map of the 18 events in the description (SlotBought only with a goal); loads the named players (ascending id) and calls `RefreshWanted` for each.
- [x] `app/domains/game/app/handlers/game/handlers/player_unbanned.rb` -- enqueue `Market::RebuildWantedJob`; `season_published.rb` -- enqueue `Market::RebuildAllWantedJob` after the goal drop.
- [x] `config/initializers/event_store.rb` -- subscribe `WantedRefresh` right after `GoalsReached` (one-line why), `PlayerUnbanned` handler to `Accounts::PlayerUnbanned`.
- [x] `release_player.rb` -- `Market::RefreshWanted.call(player)` after the goals, custom sets and holdings are deleted.
- [x] `queries/game/market/wanting_players.rb` -- table read: card's id and rarity, `in_play.counting_at`, except, distinct sorted ids.
- [x] `queries/game/market/wanted_counts.rb` -- `WantedCounts.call(card_ids, except:)` → `{ [card_id, "rare"] => distinct players }` (default 0), one query (cross join of the five tiers).
- [x] `queries/game/market/wanted_card_ids.rb` -- the viewer's own distinct card ids, sorted; `[]` for nil.
- [x] `markets_controller.rb` -- `wanted_card_ids` from `WantedCardIds`; chip shown when it is not empty; pass the ids to `ListingMarks.for`.
- [x] `listing_marks.rb` -- `Mark` gains `wanted` (from the ids); `wanted?` reads it; `goal_numbers` = `owned? ? [] : goals.map(&:position)`; `market_helper.rb` state order wanted, owned, missing.
- [x] Locales -- `wanted_spoken`: fr "voulue", en "wanted".
- [x] Tests -- `test/domains/game/market/wanted_refresh_test.rb` (after PlaceOrder, CancelOrder, SellToOrder, ApplyWantedChoices, EntrustCards, OpenPack, AcceptTrade, a closed auction, AddGoal, RemoveGoal, EditCustomSet, DeleteCustomSet, goal completion, season publish with jobs drained, and the four not-yet-published events published under the lock: rows equal a fresh `RebuildWanted`, with expected rows asserted in key cases; removed and unban cases; lock assertion; ReleasePlayer clears), `wanted_counts_test.rb`, `wanting_players_test.rb` (order rarity, banned with rows, except), `wanted_write_guard_test.rb`, a migration-shape check in a model test (checks refuse bad reason/rarities), and the adjusted tests in the Code Map plus a controller case: an open order marks its game VOULUE and the chip counts it.

**Acceptance Criteria:**
- Given a signed-in player with an open order on a game listed on the market and no goal, when they open ANNONCES, then the tile reads "Voulue", its accessible name ends ", voulue", and the VOULUES chip counts it and keeps it.
- Given any event of the list, when its operation commits, then each named player's rows equal a fresh `RebuildWanted`.
- Given the migrations on an empty PG18 database, when the schema is dumped, then it equals `db/schema.rb`.

## Implementation Notes

- `WantedRefresh::PLAYERS` maps the 16 events the description names (the "18" above miscounts); `SlotBought` refreshes only when `goal_id` is set.
- The VOULUES chip now shows when the viewer has at least one wanted row (before: whenever they had a goal).
- `ReleasePlayer` runs before `deleted_at` is set, so a deleting player's still-open orders leave order rows behind; reads skip them through `in_play`, and they go once a later story withdraws those orders.
- Not wired (outside the description): `LibrarySetSynced` and the Steam library sync turning off change a library set's games without `CustomSetEdited`/`CustomSetDeleted`, so a goal on a library set refreshes only on the next listed event.
- Benchmark run by the orchestrator (`RAILS_ENV=test bin/rails game:benchmark_open_pack`, local i7-1195G7, PG18): worst POST /en/packs p95 65.4 ms with the refresh (55.3 ms before it, same machine; part of the run overlapped a test run), limit 200 ms. The benchmark's players have no goals or orders, so the figure bounds the refresh's fixed cost only (about 5 queries per opening).

## Plan Change Log

## Review Triage Log

## Design Notes

The author already decided (epic Notes, 2026-11-20) that entry 22, built right after this one, moves the refresh after an event into `RefreshWantedJob`, because an inline refresh measured about 75 ms on POST /packs p95. This story still builds the inline refresh as its description says and records the benchmark figure here; the benchmark seeds players without goals or orders, so its figure bounds the refresh's fixed cost only.

The VOULUE state now comes first: an owned game with an open order reads "Voulue" (the tag's rule), losing its "Possédée ×n" line on that tile.

## Verification

**Commands:**
- `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_mv_schema SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- expected: only the new table in the diff
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_mv PARALLEL_WORKERS=4 bin/rails test test/domains/game/market test/domains/game/goals_reached_test.rb test/domains/game/achievements_test.rb test/domains/game/custom_set_operations_test.rb test/domains/game/goal_operations_test.rb test/controllers/market_wanted_cards_test.rb test/controllers/accounts_controller_test.rb test/domains/accounts test/jobs/wanted_card_notice_job_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched files -- expected: pass
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` (no DATABASE_URL) -- expected: worst POST p95 recorded here

## Auto Run Result

- **Summary:** `game_market_wanted` (one row per player, game and reason; an order row with the tiers `Order.reaching` gives it) is written only by `Game::Market::RefreshWanted` under the player's bank lock; the `WantedRefresh` handler, subscribed right after `GoalsReached`, runs it for every player the 16 listed events name; `RebuildWanted` (operation), `RebuildWantedJob` (unban) and `RebuildAllWantedJob` (season publish, and the release's data migration) rebuild it; `GoalsReached` and `Achievements` hear `OrderServed`, `WantedChoicesApplied` and `ArchivePurchased`; `WantingPlayers` and the new `WantedCounts` read the table, skipping removed players and the given player; the VOULUE tag and VOULUES chip read the viewer's own rows, so an open order marks its game; the tag's spoken form is now "voulue" / "wanted".
- **Files:** migrations `20261123100000_create_game_market_wanted.rb` and `20261123100001_rebuild_game_market_wanted.rb`, `db/schema.rb`; models `wanted.rb`, `refresh_wanted.rb`, `bank_lock.rb` (`held?`); operation `rebuild_wanted.rb`; jobs `rebuild_wanted_job.rb`, `rebuild_all_wanted_job.rb`; handlers `wanted_refresh.rb`, `named_players.rb`, `player_unbanned.rb`, `goals_reached.rb`, `achievements.rb`, `season_published.rb`; event `wanted_choices_applied.rb` (`buyer_ids`, `player_ids`); `release_player.rb`; queries `wanting_players.rb`, `wanted_counts.rb`, `wanted_card_ids.rb`; `markets_controller.rb`, `listing_marks.rb`, `market_helper.rb`; `config/initializers/event_store.rb`; `en.yml`, `fr.yml`; tests `wanted_refresh_test.rb`, `wanted_counts_test.rb`, `wanting_players_test.rb`, `wanted_test.rb`, `wanted_write_guard_test.rb`, and adjusted `market_wanted_cards_test.rb`, `achievements_test.rb`, `accounts_controller_test.rb`, `wanted_notices_test.rb`, `test/system/market_filters_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** the plan's targeted tests 1340 runs green; the implementer's wider pass (test/domains/game, market controllers, helpers, player stream) 2544 runs green; schema regenerated from the migrations on PG18 identical to `db/schema.rb`; zeitwerk, packwerk, planning-id, file-size checks and rubocop on the 33 touched Ruby files pass; benchmark worst POST p95 65.4 ms (limit 200). System test `market_filters_test.rb` updated but not run.
- **Residual risks:** a deleting player's still-open orders leave order rows until the removal story withdraws them (reads skip them); a goal on a Steam library set is not refreshed by `LibrarySetSynced` or the sync turning off (not in the list); the data migration runs application code, so a later schema change to goals, orders or holdings may need it guarded; `RebuildAllWantedJob` reports a player's failure and goes on, so a migration failure for one player does not stop the deploy; the writer guard sees single-line writes only; the inline refresh moves to a job in entry 22.
