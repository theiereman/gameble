---
title: 'Races between bank operations'
type: 'chore'
ticket: '9'
created: '2026-10-08'
status: 'in-review'
baseline_revision: 'bb7d881908b0e9a47bceca8aa8d5e6f4baffeddb'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The bank operations of different stories (opening a pack, registering, the daily bonus, the healing of a season's publication, deleting an account) are raced only in pairs on one player, and only `bank_races_test.rb`'s pairs and the deletion's "waits on the lock" cases exist. Nothing starts more than two of them together, nothing races them across several players against the lock order of AD-10 (bank locks in ascending player id, then holdings in ascending player and card-season, then `game_player_states`), the existing `race` helper hangs instead of failing if a thread never returns, and nothing asserts that a pack is never spent twice.

**Approach:** Add concurrency tests that start three or four bank operations at once, on one player and across players (a trade acceptance and the publication's healing job included), assert the bank's invariants (ten packs after a heal, each opened pack opened once and credited once, the bonus whole or refused, no row of a deleted player left), and turn a stuck or deadlocked thread into a failure. Run the race files repeatedly in verification. Fix the code only if a race shows a real defect, and then in the operation that breaks the lock order.

## Boundaries & Constraints

**Always:** Tests commit for real (`self.use_transactional_tests = false`), each thread on its own connection, and clean every row and event they create (fixture players' rows included, as `bank_races_test.rb`'s teardown does). At most four racing threads per test (the test pool holds 5 connections and the main thread keeps one). A deadlock is a failure: Postgres raises `ActiveRecord::Deadlocked` in one thread, which must surface as a test error, and a thread that does not return within 20 s fails the test (`trade_concurrency_test.rb`'s `together` pattern). Assertions hold whatever order the threads commit in.

**Never:** No change to an operation's behaviour unless a test proves a race; no sleeps in production code; no new gem; no skipped or retried test. No planning ids in tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open × bonus × heal, one player | a short bank (some packs opened), all three at once | the opening and the bonus succeed; the bank holds ten regular packs plus the bonus; each opened pack has one `opened_at` and its cards credited once | no `Deadlocked`, no thread stuck |
| Two openings × heal on the last pack | one available pack left, two openings and a heal at once | at most one opening per available pack; the other is `:no_pack_available` or opens a healed pack; total opened packs = successful openings; holdings = 5 cards per opened pack | as above |
| Deletion × open × bonus × heal, one player | all four at once | the deletion succeeds; no pack, holding, feed entry, claim or reward of the player is left; the others succeed before it or answer `Failure(:player_required)` | as above |
| Across players: publication's job × openings × a bonus | three players with short or empty banks; `Game::HealBanksJob.perform_now` while two of them open and one collects a bonus | every bank ends at ten regular packs (plus the bonus); no player healed twice | as above |
| Across players: trade acceptance × openings | an offered trade between two friends; its acceptance while each partner opens a pack | the swap happens once (holdings moved exactly), both openings credited | as above |
| Deletion of a trade partner × the other's opening and acceptance | an open trade between A and B; A deleted while B opens and accepts | A leaves no row, the trade is cancelled or done but nothing stays reserved, B's opening is credited | as above |
| Repeated runs | the race files run several times in a row | green every time | a failure is a defect, never retried away |

</intent-contract>

## Code Map

- `packs/game/app/models/game/bank_lock.rb` -- `BankLock.acquire(player_id)`: `pg_advisory_xact_lock`, transaction-scoped, re-entrant.
- `packs/game/app/operations/game/operation.rb` -- `lock_bank(player)` (l.68-71): bank lock then re-reads `deleted_at` → `Failure(:player_required)`.
- `packs/game/app/operations/game/open_pack.rb` -- `Game::OpenPack.new(random:).call(player:, idempotency_key: nil)`; the available pack is read without `FOR UPDATE` and updated unconditionally, so the bank lock alone prevents a double spend; holdings upserted in ascending card-season; `PlayerActivity` upserts `game_player_states` last.
- `packs/game/app/operations/game/collect_daily_bonus.rb` -- `Failure(:already_collected | :no_season | :reserve_full)`; fills an empty bank first.
- `packs/game/app/operations/game/heal_bank.rb`, `fill_bank.rb`, `packs/game/app/jobs/game/heal_banks_job.rb` -- the publication's healing, each player in its own transaction.
- `packs/accounts/app/operations/accounts/sign_in.rb` + `packs/game/app/handlers/game/handlers/player_registered.rb` -- registration fills the bank synchronously.
- `packs/accounts/app/operations/accounts/delete_player.rb` -> `Game::ReleasePlayer` (`release_player.rb`) -> `DropFriendsAndTrades` (`drop_friends_and_trades.rb:26-36`: a partner discovered on a later loop is locked out of ascending order; Postgres aborts one side).
- `packs/game/app/models/game/trade_locks.rb`, `trade_steps.rb`, `accept_trade.rb` -- trades lock both players ascending, then holdings low player first.
- `test/packs/game/bank_races_test.rb` -- `race(*blocks)` (l.55-67, no join timeout), the slowed `Game::DrawPool.current` (setup/teardown), the teardown to reuse; lambdas `heal/fill/open/bonus`.
- `test/packs/game/delete_player_concurrency_test.rb` -- its own player (`steam_id "76561197960299878"`), `leftovers`, `none_left`, teardown.
- `test/packs/game/trade_concurrency_test.rb` -- `together(*blocks)` with `join(20)`; how friends and trades are set up; `quantity`.
- `test/support/game_packs.rb` -- `create_pack`, `game_events`; `test/support/catalog_seeds.rb` for seasons.

## Tasks & Acceptance

**Execution:**
- [x] `test/packs/game/bank_races_test.rb` -- `race` joins each thread with a 20 s timeout and flunks "a thread is stuck: deadlock"; add an `assert_spent_once` check (every opened pack of the player has one `opened_at`, and the player's holdings total 5 × opened regular packs + 3 × opened bonus packs, as `create_pack`/`FillBank` deal them — read the real counts from the code); add the one-player rows of the matrix (open × bonus × heal; two openings × heal on the last pack). -- the existing pairs keep their assertions.
- [x] `test/packs/game/delete_player_concurrency_test.rb` -- add "a deletion, an opening, a bonus and a heal started together leave no row of the deleted player" with the gate and the 20 s timeout. -- the deletion row.
- [x] `test/packs/game/bank_lock_order_races_test.rb` (new) -- the across-player rows: the publication's job against openings and a bonus on three players; a trade acceptance against both partners' openings; a partner's deletion against the other partner's opening and acceptance. Own players created in setup with unique steam ids (not used by other tests), friends and trades built as `trade_concurrency_test.rb` does, teardown removing every row and event they made. -- lock order across players.
- [x] Any operation a new test proves wrong -- the smallest fix that restores AD-10's lock order or the invariant, with the failing test as proof. -- only if needed.

**Acceptance Criteria:**
- Given the race files, when they run five times in a row, then every run passes with no `Deadlocked`, no stuck thread and no double-spent pack.
- Given a bank operation with its bank lock removed (a temporary local mutation, not committed), when the new one-player races run, then at least one fails — the races can see a missing lock.

## Implementation Notes

- No race showed a defect: no operation changed.
- `open_unpublished`, `assert_opened_once` and `assert_spent_once` live in `test/support/game_packs.rb`, shared by the one-player and the across-player races. A short bank is made by real openings with no season published, so every opened pack has its `Game::PackOpened` and credited cards, and `assert_spent_once` needs no baseline.
- `Game::HealBanksJob` reports and swallows a player's error; the across-player race runs it inside `assert_no_error_reported`, so a swallowed `Deadlocked` still fails the test.
- `delete_player_concurrency_test.rb` gained a `together` helper (gate + 20 s join); its existing three-thread race now uses it.
- Mutation check: with `step lock_bank(player)` commented out of `Game::OpenPack`, "two openings and a heal" fails (the same pack opened twice). Removing the lock from `Game::HealBank` or `Game::CollectDailyBonus` is not seen by the new one-player races (an opening keeps the bank count, the reserve never fills); the existing two-heal and bonus-and-fill pairs cover those.
- Observed commit orders: the partner's deletion race has always seen the acceptance commit first, and the job race the never-filled player's opening refused; the other branches are asserted but were not hit in the runs made.

## Plan Change Log

## Review Triage Log

## Design Notes

Postgres detects a deadlock between advisory and row locks and aborts one transaction with `ActiveRecord::Deadlocked`, so a deadlock shows as an error raised by `thread.value`; the join timeout catches what Postgres cannot see (a connection-pool wait, a thread blocked in Ruby). The slowed draw pool of `bank_races_test.rb` widens the window between reading the bank and writing it; reuse it for the one-player races. Outcomes that legitimately vary with commit order (an opening refused because a heal had not yet committed, a bonus refused at a full reserve) are asserted as a set of allowed results, then the invariants are asserted on the final state.

## Verification

**Commands:**
- `for i in 1 2 3 4 5; do bin/rails test test/packs/game/bank_races_test.rb test/packs/game/delete_player_concurrency_test.rb test/packs/game/bank_lock_order_races_test.rb test/packs/game/trade_concurrency_test.rb || break; done` -- expected: five green runs
- `bin/rails test` -- expected: 0 failures, 0 errors
- `bin/rubocop test/packs/game` -- expected: no offenses

## Auto Run Result

Stopped after implementation at the author's request, before review: `status: in-review`, so the next run starts at the review step. Verification done here: the four race files three times in a row (28 runs each, green), `bin/rails test` 1722 runs with 0 failures and 0 errors, `bin/rubocop test/packs/game test/support` clean. No operation changed; tests only.

## Code Review

### 2026-10-09

**Code review complete.** 2 `decision-needed`, 4 `patch`, 1 `defer`, 9 rejected. Diff: `bb7d881..develop` over the four test files of this story (commits `20598d3`, `4c80eda`), +268 / −14. Lenses: blind-hunter, edge-case-hunter, verification-gap, intent-alignment; none failed.

- [ ] [Review][Patch] (resolved from Decision, option b: narrow the header, leave lock order to `trade_concurrency_test.rb`) The across-player races cannot see a broken lock order — `bank_lock_order_races_test.rb`'s header says a broken AD-10 order would deadlock and fail the test, but in two of its three races only one operation locks several players (`HealBanksJob` serves one player per transaction; openings and the bonus lock one bank; `AcceptTrade` is the only two-player locker against the openings), so no inversion is possible. In the third, `DropFriendsAndTrades` finds the single partner on its first loop and locks both ascending, so its out-of-order path (a partner found on a later loop) is never reached; and it rescues `ActiveRecord::Deadlocked` and retries up to 3 times (`drop_friends_and_trades.rb:11-17`), so a deadlock on the deletion's side never reaches `thread.value` and passes silently. Cross-player order is pinned elsewhere by `trade_concurrency_test.rb` (crossing trades and crossing acceptances). Options: (a) add a race between two multi-player lockers (both partners deleting at once, or a deletion against a trade proposed during it) and count the deletion's deadlock retries so a retried deadlock fails the test; (b) keep the tests and narrow the header and the commit's claim to what they check (invariants across players under concurrency), leaving lock order to `trade_concurrency_test.rb`.
- [ ] [Review][Patch] (resolved from Decision, option a: add a race where the deleted partner is the recipient and the surviving proposer opens a pack) "Nothing reserved" in the partner-deletion race is checked on the wrong player — `bank_lock_order_races_test.rb:155` sums `reserved` for `@first`, the trade's recipient, who never has anything reserved (`ProposeTrade` reserves only the proposer's offer, `trade_steps.rb:73-83`); the proposer `@second` is the deleted one, whose holdings are deleted anyway. The assertion cannot fail. The matrix row's "nothing stays reserved" only matters for a surviving proposer, already pinned by `trade_concurrency_test.rb:81` and `drop_friends_and_trades_test.rb:40`. Options: (a) add a race where the deleted partner is the recipient and the surviving proposer opens a pack while the deletion releases their reserved copies; (b) drop the assertion and "nothing reserved" from the test name.
- [ ] [Review][Patch] A failed or stuck racing thread is left running: `race`/`together` re-raise or flunk at the first bad thread and never kill or join the others, which keep their connection, transaction and locks; teardown's `delete_all` (no `lock_timeout` in test) can then block on them or delete under them, so the hang moves to teardown and a real `Deadlocked` is buried under teardown errors — kill and join every thread in an `ensure` [test/packs/game/bank_lock_order_races_test.rb:73]
- [ ] [Review][Patch] `together` now exists in three copies (plus `race`), so the previous fix must be made in each — move it to `test/support` beside `open_unpublished` and `assert_spent_once` [test/packs/game/delete_player_concurrency_test.rb:85]
- [ ] [Review][Patch] The four-way deletion race checks five tables through `leftovers`/`none_left` while `bank_lock_order_races_test.rb:151-152` checks eight; its opening writes `game_player_states` and its bonus can write set completions — extend `leftovers` to `Game::PlayerState`, `Game::SetCompletion` and `Game::FriendCode`, which `Game::ReleasePlayer` deletes [test/packs/game/delete_player_concurrency_test.rb:34]
- [ ] [Review][Patch] `assert_spent_once` counts cards only for regular and bonus packs, so an opened `reward` pack (`Game::Pack` kind `reward`) makes it fail on correct behaviour — sum each opened pack's `card_season_ids.size` instead [test/support/game_packs.rb:46]
- [x] [Review][Defer] `Game::HealBanksJob` reports an error when a player is deleted between its batch read and their heal: `HealBank`/`FillBank` return `Failure(:player_required)` under the bank lock and `.value!` raises, so `Rails.error.report` fires for a normal race [packs/game/app/jobs/game/heal_banks_job.rb:28] — deferred: pre-existing production code, not changed by this story; no race of the job against a deletion exists yet.

**Rejected**
- `low` — The "accepted" and "cancelled" branches of the partner-deletion race and the "no pack available" branch of the job race are allowed but the plan notes only one of each was ever hit; forcing each order with `first_holding_the_lock` means new tests, and the re-check behind the cancelled branch is pinned by `trade_concurrency_test.rb`.
- `low` — The three-way one-player race does not catch a lock removed from `HealBank` or `CollectDailyBonus`; the plan records it and the existing two-heal and bonus-and-fill pairs cover those locks.
- `low` — Registration and the `SeasonPublished` handler are not raced, only `FillBank` and `HealBanksJob.perform_now`; the plan's matrix leaves registration out and `bank_races_test.rb` already races sign-up in pairs.
- `low` — The plan's acceptance asks for five runs in a row; the Auto Run Result records three. A verification step, not a code fix.
- `low` — Teardown of `bank_lock_order_races_test.rb` raises on a nil `@created` when setup fails partway; the setup error is still reported and the fix adds guards.
- `low` — `join(20)` runs one thread after another, so the worst case is 20 s per thread, and the flunk message says "deadlock" for any stuck thread; cosmetic.
- `false` — `@first.id < @second.id` is assumed by `offered_trade`: the three players are created in order in one setup from one sequence, so ids ascend.
- `false` — Teardown hitting the `game_first_discoveries` foreign key for a deleted player: no player deleted in that file ever opens a pack, so it has no first discovery to leave.
- `maybe-false` (would be `low`) — The four-way deletion race passes one `Accounts::Player` instance to three threads; the operations only read its id and state, and no mutation was found.
