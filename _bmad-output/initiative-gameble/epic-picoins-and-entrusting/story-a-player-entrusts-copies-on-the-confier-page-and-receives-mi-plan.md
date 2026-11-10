---
title: 'A player entrusts copies on the Confier page and receives minted PiCoins'
type: 'feature'
ticket: '1'
created: '2026-11-10'
status: 'built'
baseline_revision: '3d87c613a2f1e13d1dce6ce886a32334fc54c394'
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

**Problem:** The market has no money: no wallet, ledger, settings or way to turn a card into PiCoins.

**Approach:** Tracer through every layer: the `Game::Market` tables and models, the insert-only ledger behind `Ledger.post`, versioned settings with a first closed version at every deploy, `EntrustCards`, and a server-rendered Confier page (GET + POST) that entrusts a batch and shows the total minted. Epic requirements R1, R2, R3 (deposits only), R12, R13, R15, R16, R17, R22 (refusal), R23.

## Boundaries & Constraints

**Always:** code under `Game::Market` in `app/domains/game`, tables `game_market_*`; every write through an operation publishing one event; `Ledger.post` the only writer of wallets and entries, called once per transaction after every other lock; lock order bank lock → holdings → wallets; `ActiveRecord::Deadlocked` answers `Failure(:market_busy)`; amounts `bigint` integers; GET writes nothing; no database id in HTML or URLs (card-seasons by their public token/slug); every string in en.yml and fr.yml, `errors.game.<code>` by hand; expand/contract-safe migrations; few-sales threshold is not a setting.

**Never:** the daily cap (story 3), the PiCoin mark component (4), live preview/JS grid (5–6), card-detail entry (7), Balance chip (8), ChangeSettings or back-office (9), OpenMarket (2), reconciliation (11), archive stocks table (12); no foreign key or unique index on `listing_id` (epic 39).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Happy | open version, 2 Commons + 1 Rare free, all entrusted | holdings drop, 1 mint entry +7,000 available, deposits upserted, `CardsEntrusted` | — |
| Closed | only the first closed version | nothing moves | `market_closed` |
| Stale | form drew version N, current is N+1 | nothing moves | `amounts_changed` |
| Reserved | quantity 2, reserved 1, asks 2 | nothing moves | `not_enough_copies` |
| No rarity | card-season rarity null | nothing moves | `no_rarity` |
| Deadlock | `ActiveRecord::Deadlocked` raised | rolled back | `market_busy` |
| Empty batch | no quantity > 0 | nothing moves | `empty_batch` |
| Deploy twice | `CreateFirstSettings` run twice | one version | — |

</frozen-after-approval>

## Code Map

- `lib/application_operation.rb` -- base: `transaction`, `step`, `publish`, `failure_key` → `errors.game.<code>`.
- `app/domains/game/app/operations/game/operation.rb` -- `Game::Operation`, required `player:`, `lock_bank`, `stream_name`.
- `app/domains/game/app/models/game/bank_lock.rb`, `trade_locks.rb` -- `BankLock.acquire`, `TradeLocks.holdings(player_id, ids)` (FOR UPDATE, card-season order); reuse.
- `app/domains/game/app/operations/game/accept_trade.rb:25-28,65-79` + `trade_steps.rb` -- `move` and `ShowcaseEntry.remove_unheld`; extract into a shared step, AcceptTrade behaviour unchanged.
- `app/domains/game/app/operations/game/cancel_open_trades.rb` -- existing `rescue ActiveRecord::Deadlocked` pattern.
- `app/domains/game/app/queries/game/trade_suggestions/free_editions.rb` -- free copies with rarity/season (pass `card_ids = nil`); reuse or mirror for Confier's grid.
- `app/domains/game/app/models/game/holding.rb` -- `quantity`, `reserved`, check `quantity >= reserved`.
- `app/domains/catalog/app/models/catalog/rarity.rb`, `catalog/card_season.rb` -- `TIERS`, nullable `rarity`.
- `config/initializers/event_store.rb` -- subscriptions (none needed for `CardsEntrusted`); events subclass `RubyEventStore::Event`, ids only.
- `app/controllers/markets_controller.rb`, `app/policies/market_policy.rb`, `config/routes.rb:34` -- market scope; `goal_policy.rb` for `player?`; `ApplicationController.throttle_player` (example `achievement_claims_controller.rb:2`).
- `bin/docker-entrypoint` + `test/config/docker_entrypoint_test.rb` -- add the first-settings task next to `game:backfill_achievements`.
- `db/seeds.rb` -- idempotent blocks; add first settings.
- `db/migrate/20261109120000_create_accounts_release_notes.rb` -- migration and check style; `[8.1]`.
- `config/locales/en.yml:1230`, `fr.yml:3052` -- `errors.game`.
- `test/support/holdings.rb`, `lock_races.rb` -- helpers.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/*_create_game_market_tables.rb` -- create `game_market_settings` (insert-only; per-rarity entrustment/stamp/minimum columns, commission bp, daily cap, three durations + preselected, increment bp, soft close seconds, averaged sale count, average window days, feed threshold, unusual multiple, alert thresholds and day-of-income targets nullable, `open`, `terms_confirmed_at`, `odds_confirmed_at`, `first_opened_at`, `author_id`, `replaces_id` unique), `game_market_wallets` (player unique, available/committed ≥ 0), `game_market_ledger_entries` (player, kind check of the eight kinds, available/committed deltas, `listing_id` bigint null, settings version, created_at), `game_market_archive_deposits` (player + card_season unique, quantity > 0) -- schema.
- [ ] `db/schema.rb` -- regenerate per AGENTS.md.
- [ ] `app/domains/game/app/models/game/market/{settings,wallet,ledger_entry,archive_deposit}.rb` -- entry and settings raise on update/destroy.
- [ ] `.../models/game/market/starting_settings.rb`, `operations/game/market/create_first_settings.rb`, `queries/game/market/current_settings.rb` -- starting values from market-economy.md; idempotent first closed version; highest id.
- [ ] `.../models/game/market/ledger.rb`, `mint.rb` -- `Ledger.post`: upsert wallets, lock ascending player id, net per player, apply, insert entries; `Mint.credit`.
- [ ] `.../operations/game/move_holdings.rb` (shared step) + `accept_trade.rb` -- extracted move + showcase cleanup.
- [ ] `.../operations/game/market/entrust_cards.rb`, `events/game/market/cards_entrusted.rb`, deposit upsert -- per the matrix.
- [ ] `.../queries/game/market/entrustable_copies.rb` -- free copies with rarity, season, value.
- [ ] `app/helpers/picoins_helper.rb` -- exact (1 234 567 / 1,234,567) and compact truncated (31,5k / 7,2M) per locale.
- [ ] `config/routes.rb`, `app/controllers/market/entrustments_controller.rb`, `app/policies/market/entrustment_policy.rb`, `app/views/market/entrustments/{new,create}.html.erb` -- GET grid with copies fields and hidden version; POST throttled 10/min; result page; failures re-render with the message.
- [ ] `bin/docker-entrypoint`, `lib/tasks` or game rake task, `db/seeds.rb` -- run CreateFirstSettings each deploy.
- [ ] `config/locales/en.yml`, `fr.yml` -- copy and `errors.game.{market_closed,amounts_changed,not_enough_copies,no_rarity,market_busy,empty_batch}`.
- [ ] `test/support/market.rb` -- `open_market!` inserts an open version.
- [ ] Tests: `test/domains/game/market/{ledger,entrust_cards,create_first_settings,ledger_write_guard}_test.rb`, AcceptTrade suite unchanged, `test/helpers/picoins_helper_test.rb`, `test/controllers/market/entrustments_controller_test.rb`, `test/system/market_entrust_test.rb`, docker entrypoint test.

**Acceptance Criteria:**
- Given an open market, when a player enters copies of two editions on Confier and validates, then the result shows the total minted and the count, and the collection holds fewer copies.
- Given any file outside `Ledger`, when the write-guard test scans `app/` and `lib/`, then no reference to wallet or entry write methods exists.
- Given the first closed version only, when a visitor or player opens Confier, then the page renders without writing and validation answers `market_closed`.

## Design Notes

`Ledger.post` is the only writer: callers build entry hashes, Ledger nets per player so one wallet row updates once. Settings rows are versions: never updated, a change inserts a row with `replaces_id`. Deposits survive account deletion (no FK cascade from players; `player_id` kept).

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers/market test/helpers` -- pass
- `bin/rails test test/system/market_entrust_test.rb` -- pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references` -- clean

## Change Log

- 2026-11-10 review: read the diff against the plan, spec and AGENTS.md (ledger single writer and ascending lock order, lock order bank then holdings then wallets, GET without writes, tokens and slugs instead of ids, policy on both actions, en/fr keys with French zero forms, packwerk, file sizes, planning ids). No defect found, no code change. Rubocop and packwerk could not run in the worktree (gems missing); ruby -c and prettier pass.
