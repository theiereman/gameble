# Review: reality check of the 2026-11-09 market update (AD-40 to AD-49, amended AD-10, AD-13, AD-14)

Independent reviewer, 2026-11-09. Lens: was every committed claim checked against reality, or just asserted? Scope: `git diff HEAD -- architecture-gameble.md`, the ten new ADs and the amended lines, against the working tree at `bdbebce1` on `review/luck-tracker`.

Read: `app/domains/game/app/models/game/{bank_lock,trade_locks,visibility,showcase_entry,set_tier}.rb`, `lib/application_operation.rb`, `app/domains/game/app/operations/game/{operation,receive_season_allocation,accept_trade,trade_steps,cancel_open_trades,release_player,drop_friends_and_trades,expire_trade,sum_weekly_goal,publish_weekly_verdict}.rb`, `app/domains/game/app/jobs/game/{drop_friends_and_trades_job,expire_trades_job,sum_weekly_goal_job}.rb`, the `player_deleted`, `player_banned` and `visibility_changed` handlers, `app/domains/game/app/queries/game/{feed_entries,visible_feed_entry,held_copies,friendship_between,season_allocation_recap}.rb`, `app/domains/accounts/app/operations/accounts/{delete_player,delete_inactive_player,erase_banned_player,sign_in_through_identity,create_announcement,announcement_writing,show_announcement}.rb`, `app/domains/accounts/app/jobs/accounts/apply_retention_job.rb`, `app/controllers/application_controller.rb` and the `rate_limit` call sites, `app/controllers/cards_controller.rb` (pioneer), `app/helpers/feed_helper.rb`, `config/recurring.yml`, `config/queue.yml`, `config/initializers/{event_store,strong_migrations,active_job}.rb`, `db/schema.rb`, the last five migrations, commit `bdbebce1`, `app/domains/game/package.yml`, the spec lines on the pioneer and CAP-33, and the installed sources of strong_migrations 2.8.0 and solid_queue 1.7.0.

No web lookup was needed: every Rails and Solid Queue question was answered by the installed gem source or by the repo already doing the same thing in production. Nothing was run against a database, so the `IN` predicate point (F5) rests on commit `bdbebce1`, not on a reproduction.

**Verdict: pass with fixes, no critical finding.** No new gem is implied, and the storage, scheduling, rate-limit and locking mechanisms all exist and fit. The weak spot is the seam with existing code: one named class does not exist, a base class refuses the shape AD-45 needs, one job comparison is false, and account deletion already removes rows that AD-46 and AD-49 assume are still there.

---

## Findings

### F1: `Game::SystemOperation` does not exist, and `Game::Operation` refuses an operation with no `player:` (high; AD-14, AD-45, AD-48)

- `grep -rn SystemOperation app lib test config` returns nothing. The name appears only in the architecture (AD-14, AD-48).
- The operations that really write no-player rows inherit `ApplicationOperation` directly: `Game::SumWeeklyGoal`, `Game::CreateWeeklyGoal`, `Game::RecordPlayerActivity`.
- `Game::Operation.method_added` raises `ArgumentError` at class load unless `call` has a required `player:` keyword. AD-45's `CloseAuction` is described by listing only, and AD-42's `ChangeSettings` by staff. Written as described on `Game::Operation`, the first fails when the class loads.
- AD-48's alt-signal rows are "one row per account and signal", so AD-14's "writes only rows belonging to no player" does not cover them, whichever base class is chosen. It needs either a per-player run or a stated exception for this staff-only table.

Fix:
- Either create `Game::SystemOperation < ApplicationOperation` in the market's first ticket and state that, or replace the name with "`ApplicationOperation`, as `Game::SumWeeklyGoal`". The first keeps AD-14 readable.
- State in AD-45 that `CloseAuction` takes `player:` (the seller) with `require_account`, exactly as `ExpireTrade` does for the proposer (`ExpireTradesJob` passes it). `require_player` would refuse the banned sellers AD-46 needs it to close.
- State in AD-42 that `ChangeSettings` takes `player:` (the administrator).
- Add alt signals to AD-14's exception, or make that job per-player.

### F2: account deletion already removes the rows AD-46 and AD-49 assume survive it (high; AD-14, AD-45, AD-46, AD-49)

`Accounts::DeletePlayer` publishes `PlayerDeleted`, and `Game::Handlers::PlayerDeleted` runs `Game::ReleasePlayer` synchronously in that transaction. It does `Holding.where(player_id:).delete_all` and `FeedEntry.where(player_id:).or(FeedEntry.where(partner_id:)).delete_all`. AD-14's list names neither, and the market ADs were written as if they did not happen. Consequences:

1. **The sale feed entry never reads "anonymous" for a deleted player.** AD-49 says a deleted player "prints the anonymous locale key". Once either party deletes their account, the entry is gone. CAP-33 and the pioneer only need this for the bid history and the card detail, so dropping the entry may be acceptable, but the AD promises otherwise.
2. **Banned or non-public players' sale entries are filtered out today.** `FeedEntries.visible` and `VisibleFeedEntry` keep an entry only when every named player passes `visible?`. AD-13's "name-only surfaces excepted" requires a per-kind exception in both queries. Neither is mentioned.
3. **AD-46's "the reservation is released" has no row to act on** for a deleted seller. `TradeSteps#release` tolerates that (`offer.slice(*holdings.keys)`), but a step written from AD-46's wording may not.
4. **AD-45 reads seller and leader without a lock and rechecks only open, due and leader.** AD-46 needs the removed check as well, and it must run after the bank locks, or a deletion committing in between reaches settlement with the seller's holding gone. `AcceptTrade#move` would then try `Holding.insert_all!` with quantity -1. The check constraint would roll it back and the next run would self-heal, but it reports a false error. `Game::Operation#lock_bank` is the precedent: it rechecks `deleted_at` after the lock.

Fix:
- AD-14: say that deletion removes holdings and feed entries.
- AD-49: remove the market sale's feed entry from the anonymous case for deletion, or exclude that kind from `ReleasePlayer`. Decide which.
- AD-13 or AD-49: name the two feed queries that need the exception.
- AD-46: "the reservation is released if the holding still exists".
- AD-45: add "and that seller and leader are not removed, read after the bank locks" to the recheck.
- AD-46: `ReleasePlayer` should also delete the outbid notice rows of AD-44; AD-14's "data left behind by a deletion" applies to them.

### F3: `DropPresenceJob`'s per-player operation cannot follow AD-10's lock order or AD-41's single call as written (high; AD-10, AD-41, AD-46)

The operation handles every listing and leading bid of a removed player. Each one has a different counterparty, and AD-44 and AD-45 settle that the counterparty's bank lock is taken before the listing lock. Counterparties are only known by reading the listings, so one transaction spanning several must either:
- discover them and retry on deadlock, which is what `CancelOpenTrades#lock_open_trades` had to do (a loop, a savepoint and `rescue ActiveRecord::Deadlocked`); or
- take bank locks after a listing lock, which breaks AD-10.

AD-41's "one transaction makes one call" to `Ledger.post` would also force all the releases into one batch.

Fix: state in AD-46 that the job calls one operation per listing (`player:` the removed player, plus the listing), one transaction each, like `CloseAuction` (read the parties without a lock, bank locks ascending, lock the listing, recheck), and posts the `forfeit` in a final per-player operation once none remain. This also limits one bad row to one listing.

### F4: "runs every minute, like `DropFriendsAndTradesJob`" is false (medium; AD-46)

`DropFriendsAndTradesJob` is not in `config/recurring.yml`. It is run only by a rake task (`app/domains/game/lib/tasks/game.rake:66`) as a backfill. Live handling is synchronous, in the `PlayerBanned` and `PlayerDeleted` handlers. The one-minute job in production is `ExpireTradesJob`.

The design still stands: a job is what keeps a handler from writing another player's wallet. But the precedent is wrong, and a builder taking it at face value would not add a schedule.

Fix: "runs every minute, like `ExpireTradesJob`", and add both market recurring entries to the `development` and `production` blocks of `config/recurring.yml`.

### F5: writing the partial index with `IN` would drift `db/schema.rb` (medium; AD-41)

`db/schema.rb` can express what the ADs need: partial unique indexes via `where:`, and `t.check_constraint`, are both already used. But the latest commit, `bdbebce1`, had to rewrite a `state IN (...)` check as `state = 'draft' OR ...` because it did not survive a schema load and dump on Postgres 18. The `kind` checks and partial indexes already in the schema use `=` and `OR`, never `IN`. `kind` on the ledger is a string with four values, so `kind IN ('stamp', 'purchase', 'sale', 'commission')` is the natural way to write AD-41's index and would hit the same drift, which CI refuses. I did not reproduce this on an index predicate.

Fix: state in AD-41 that the predicate is written as `kind = 'stamp' OR kind = 'purchase' OR ...`, and write each of the market's check constraints the same way.

### F6: AD-10 and AD-45 leave `reached_by` undefined for a market purchase (medium; AD-10, AD-45)

A market purchase is now an operation that raises quantities, and AD-10 keeps "a pack, a trade or the allocation". `game_set_tiers_reached_by_values_check` and `SetTier::REACHED_BY` accept only those three. `Game::SeasonAllocationRecap` filters on `reached_by: %w[pack trade]`, so a new `market` value would silently leave tiers out of the recap. `FeedEntry`'s tier-grouping SQL also joins on `reached_by`.

Fix: state in AD-45 that a market purchase records `reached_by: "trade"`, the smallest change. If the distinction is wanted, name `market` and list the check, the constant and the recap as its costs.

---

## Lower-priority notes

- **AD-49 and `staff_sees_all`:** `visible?` defaults to `staff_sees_all: true`, which returns true for a banned owner before the ban check. Both existing callers on this kind of surface (`FeedEntries`, `CardsController#pioneer_line`) pass `false`. The component should too, and should test `removed?` first. Live players can also have a nil `persona_name`, so it needs `Accounts::PersonaName.clean` with a fallback, as other surfaces do.
- **AD-49 and the shipped pioneer row:** `CardsController` shows "anonymous" for any viewer `visible?` refuses, so a private player is anonymous today. AD-49 prints the name with no link. Spec lines 93 and 139 back this (author, 2026-11-09), so this is a behaviour change to build, not an error. The key `card_details.pioneer.anonymous` needs a more general home.
- **AD-49 on a public stream:** the viewer is unknown at broadcast, so a friends-only bidder has no link until the page is reloaded. The existing feed has the same limit (`links:`). Acceptable; a ticket should say so.
- **AD-43's shared step:** `AcceptTrade#move` is private to `AcceptTrade`, not in `TradeSteps`, so it has to be extracted first. `ShowcaseEntry.remove_unheld(player_id, card_season_ids)` fits as named.
- **AD-42 and `CreateAnnouncement(staff:, message_fr:, message_en:, shown:)`:**
  - It exists and `Game -> Accounts` allows the call; `Steam::PromoteImport` calling `Catalog` is the cross-pack precedent.
  - Messages are limited to 280 characters, which a change touching many values could exceed.
  - `shown: true` hides any banner currently shown.
  - Its `Failure(:invalid_announcement)` resolves to `errors.accounts.*`, so the caller has to map it.
  - AD-42 names no event of its own for `ChangeSettings`, though AD-10 requires one primary event.
- **AD-45's job:** a partial index on `ends_at` where the status is `open` is implied by a scan every 10 seconds and should be stated.
- **Existing `game_feed_entries` constraints:** the sale kind needs the two-migration replacement already used by `AddVerdictToGameFeedEntries` and `ValidateGameFeedEntriesVerdict`.

## Verified

| Claim | Evidence |
| --- | --- |
| `Game::BankLock` is a per-player transaction-scoped advisory lock, re-entrant within a transaction | `bank_lock.rb` (`pg_advisory_xact_lock`) |
| `Game::TradeLocks` gives players ascending and holdings by card-season | `trade_locks.rb` |
| `Game::Visibility.visible?(viewer, owner)` and `open_to_friends?` exist with the semantics used; a nil viewer is safe | `visibility.rb`, `friendship_between.rb`, `Player.acting_staff?` |
| `ShowcaseEntry.remove_unheld` exists and fits | `showcase_entry.rb` |
| `ReceiveSeasonAllocation` runs inside a settlement; its bank lock is re-entrant and it accepts a removed-safe account | `receive_season_allocation.rb` (`require_account`) |
| `ApplicationOperation` nests through `step`; `Failure(:code)` maps to `errors.game.*` from the first segment, so `Game::Market` keys stay under `errors.game` | `lib/application_operation.rb` |
| Rate limiting per player exists | `ApplicationController.throttle_player`, Solid Cache in production |
| A 10-second schedule is fine under Solid Queue | `sum_weekly_goal` and `broadcast_goal` already run it in production. Fugit parses it to the six-field `*/10 * * * * *` as a `Fugit::Cron`, which `RecurringTask` requires. Enqueue is deduplicated per `run_at` only, so a slow run can overlap the next; `CloseAuction`'s recheck under locks makes that harmless |
| The job pattern (per-row operation, report and move on) exists | `ExpireTradesJob` |
| Jobs enqueue after commit | `config/initializers/active_job.rb` |
| Partial unique indexes and check constraints are expressible in `schema.rb` | many in `db/schema.rb`; see F5 for the predicate form |
| strong_migrations allows indexes and checks on a new table in its `create_table` | `checks.rb` (`new_table?`), `CreateAccountsReleaseNotes` |
| "A player's rows are anonymised, never deleted" | `DeletePlayer` updates the row. `DeleteInactivePlayer` and `EraseBannedPlayer` delegate to it. No foreign key to `accounts_players` cascades. The only hard delete is `SignInThroughIdentity`'s compensating `player.delete` for a row created moments before in a lost race, which can have no ledger entries |
| First discoveries keep their player | `ReleasePlayer` only nulls `pack_id` |
| Going private does not touch listings | `CancelOpenTrades` releases trade lines only; no code zeroes `reserved` |
| Tables are prefixed by pack and checks are named per table | `db/schema.rb` |
| Packwerk allows `Game -> Accounts`; `Game::Market` follows the nested-namespace precedent | `app/domains/game/package.yml`, `Game::TradeSuggestions` |
| No new gem is implied | every mechanism above uses gems already in `Gemfile.lock` |
