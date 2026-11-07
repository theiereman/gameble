---
title: 'Two friends can hold any number of open trades'
type: 'feature'
ticket: '8'
created: '2026-11-01'
status: done
baseline_revision: '573cd786934250bcac8d3c4d12c9ca4c2d8729df'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Two friends can hold only one open trade (a partial unique index, a refusal in `Game::ProposeTrade` and a redirect in the new-trade page), so a second proposal, and later a trade suggestion, waits behind the first.

**Approach:** Lift the limit as AD-8 states: drop the index concurrently, remove the one-trade check, redirect and lookup, refuse only a proposal identical to one the same player already has open with that friend (`Failure(:trade_already_sent)`), make every trade button open the friend's new-proposal draft, and let the remove-friend dialog count the trades it cancels.

## Boundaries & Constraints

**Always:**
- The identical-proposal check runs inside `ProposeTrade`'s transaction right after `TradeLocks.players`, against trades with `status: "open"` and `expires_at > now` whose `proposer_id` is the player and `recipient_id` the friend; equal means the same `{card_season_id => quantity}` hash for the offer side and for the request side (an empty offer equals an empty offer).
- Reservations, acceptance and counter rules stay exactly as they are; each trade reserves only its own offer.
- `ÉCHANGE`/`ÉCHANGER`/`TRADE` buttons on the friend row, the friend profile dialog, the public profile and the friend chooser link to `new_trade_path(friend: token)`, never to a trade.
- The remove-friend dialog counts the friend's trades with `status: "open"` (what `CancelOpenTrades` cancels) and pluralises: one "Votre échange en cours avec %{name} est annulé et ses cartes sont libérées." / other "Vos %{count} échanges en cours avec %{name} sont annulés et leurs cartes sont libérées."; English follows the existing line; French plural keys need a `zero` form.
- Every string in both `en.yml` and `fr.yml`; `errors.game.trade_already_sent` added by hand in both (i18n-tasks cannot see dynamic error keys).
- Strong migrations: the index removal is its own migration with `disable_ddl_transaction!` and `algorithm: :concurrently`; regenerate `db/schema.rb` from the migrations as AGENTS.md describes.

**Never:** no guard on `CounterTrade`; no cap on trades per pair; no change to the trade board TypeScript or the draft key; no edit of the old `create_game_trades` migration; no database id in any URL or HTML.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Second trade | A has an open trade to B; A proposes different terms to B | A second open trade; each reserves its own offer | No error expected |
| Opposite trade | A→B open; B proposes to A | Both open | No error expected |
| Identical resend | A→B open with offer X, request Y; A sends X, Y again | No new trade, no reservation change | `Failure(:trade_already_sent)`, back on the draft with the refusal |
| Identical but expired | The identical trade is past `expires_at`, unswept | A new trade opens | No error expected |
| Identical from the other side | B→A open with X/Y; A sends X/Y to B | A new trade opens (different proposer) | No error expected |
| Racing duplicates | Two identical proposals at once | One trade | The other `trade_already_sent`, no deadlock |
| Remove friend | Two open trades with B | Dialog names 2; both cancelled, all reservations released | No error expected |

</intent-contract>

## Code Map

- `db/migrate/20261007130000_create_game_trades.rb:19` -- created `index_game_trades_one_open_per_pair` (`low_player_id, high_player_id`, unique, where status open); read only.
- `db/schema.rb:570` -- the index line to disappear after regeneration.
- `app/domains/game/app/operations/game/propose_trade.rb` -- `call` order: require_player, normalise_offer/request, known_cards, other_player, `expire_due_trade` (l.11), then transaction: `TradeLocks.players` (l.14), friends, `no_open_trade` (l.16), requestable, holdings lock, enough_copies, create_trade/items, reserve, publish. Remove the `RecordNotUnique` rescue (l.28-31), `no_open_trade` (l.40-42) and `expire_due_trade` (l.44-51); keep `pair` (l.53-56, used by `create_trade`).
- `app/domains/game/app/operations/game/trade_steps.rb` -- `normalise` (l.13-20) gives sorted `{id => qty}`; `side_of(trade, side)` (l.77-79) returns the same shape: reuse it for the comparison, loading items for all candidate trades in one query.
- `app/domains/game/app/models/game/trade.rb` -- `in_progress` = status open (includes expired-unswept); `due(now)`.
- `app/controllers/trades_controller.rb` -- `new` l.33-37 redirect via `open_trade_with` (l.157-159) and `trades.one_at_a_time`: remove both, keep `@trades` for `card_views`; `create` failure already returns to `new_trade_path(friend:)` through `refused`.
- `app/domains/game/app/queries/game/open_trades_by_friend.rb` -- `{friend_id => token}`; replace with a per-friend count of `status: "open"` trades (rename to e.g. `Game::OpenTradeCountsByFriend`) or delete; callers: `friends_controller.rb:9`, `friend_profiles_controller.rb:13`, `public_profiles_controller.rb:66`.
- Views: `friends/show.html.erb:76,84`, `friends/_friend_row.html.erb:10-12`, `friend_profiles/show.html.erb:20,29`, `public_profiles/show.html.erb:8` → `_profile.html.erb` → `_summary.html.erb` → `_action.html.erb:19` (drop the `open_trade_token` locals), `friends/_remove_dialog.html.erb:16-18` (count instead of flag), `trades/_chooser.html.erb:17-18` (already links to new; no change).
- `app/domains/game/app/operations/game/remove_friend.rb`, `cancel_open_trades.rb` -- already cancel every open trade; no change.
- Locales: delete `trades.one_at_a_time.*` (en 2566-2568, fr 1624-1626) and `errors.game.trade_already_open` (en 994-995, fr 2285); add `errors.game.trade_already_sent`; pluralise `friends.remove_dialog.trade` (en 1123, fr 1468), following the going-private plural at en 2223-2225 / fr 1336-1338.
- `app/models/player_stream.rb:79` uses `Game::Counterparts` -- check duplicates of a partner id are harmless.

## Tasks & Acceptance

**Execution:**
- [ ] `db/migrate/<timestamp>_remove_game_trades_one_open_per_pair_index.rb` -- concurrent `remove_index` by name -- AD-8 Costs.
- [ ] `db/schema.rb` -- regenerate from the migrations on Postgres 18 per AGENTS.md -- CI drift check.
- [ ] `app/domains/game/app/operations/game/propose_trade.rb` -- remove the per-pair check, rescue and expiry; add the identical-proposal refusal -- AD-8.
- [ ] `app/controllers/trades_controller.rb` -- remove the redirect and `open_trade_with` -- a draft always opens.
- [ ] `app/domains/game/app/queries/game/open_trades_by_friend.rb` and its three controllers and the views above -- buttons always open the new-proposal draft; the dialog gets a count -- EXPERIENCE.md Amis.
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- remove, add and pluralise the keys above.
- [ ] Tests -- rewrite or delete the ones asserting one trade per pair: `test/domains/game/trade_test.rb:95,105`, `trade_accept_counter_expire_test.rb:435`, `trade_concurrency_test.rb:162` (opposite proposals both open; add a race of two identical proposals → one `trade_already_sent`), `open_trades_by_friend_test.rb`, `test/controllers/trades_controller_test.rb:256,772,877`, `test/system/trades_test.rb:523`, `test/controllers/friends_controller_test.rb:64,201,276,335`, `friend_profiles_controller_test.rb:135`, `test/system/friends_test.rb:159,171`; add the I/O matrix rows as operation tests and a remove-friend test with two trades.

**Acceptance Criteria:**
- Given a player with an open trade to a friend, when they press ÉCHANGE on the friend's row, the friend profile or the public profile, then the new-trade board opens with their stored draft, not the open trade.
- Given two open trades with a friend, when the player opens the remove dialog, then it says both are cancelled, and confirming cancels both and frees every reserved copy.
- Given an identical proposal already open, when the player sends it again from the board, then they land back on the draft with the trade_already_sent message in their language and no second trade exists.

## Implementation Notes

- Migration `db/migrate/20261101100000_remove_game_trades_one_open_per_pair_index.rb`: concurrent `remove_index` that names the columns, `unique` and `where`, so it rolls back. `db/schema.rb` was regenerated from the migrations on the test database; the diff is only the index line and the version. The CI build and round-trip checks pass.
- `Game::ProposeTrade`: removed `no_open_trade`, the `RecordNotUnique` rescue and `expire_due_trade`. `not_already_sent` runs right after `TradeLocks.players`, before `friends`. It plucks the ids of this proposer's open, unexpired trades to the friend, loads their items in one `TradeItem` query, and compares `{ "offer" => {...}, "request" => {...} }` with the normalised sides. `now` is taken once under the lock and reused for the new trade. `side_of` is per trade, so a small `sent_terms` helper builds every candidate's sides at once.
- Behaviour change that comes with dropping `expire_due_trade`: a trade past `expires_at` that has not been swept yet keeps its offered copies reserved until `Game::ExpireTradesJob` runs (every minute). Before, proposing to that friend expired it first. Tests now cover this: `trade_accept_counter_expire_test` (a new proposal sits beside the due trade; the recipient's proposal opens and the sweep then expires only the due one) and `trades_controller_test` (the same terms resent after expiry, unswept, open a new trade).
- `Game::OpenTradesByFriend` was replaced by `Game::OpenTradeCountsByFriend` (`{ friend_id => count of status open }`, with expired-unswept trades included, which matches what `CancelOpenTrades` cancels). `FriendsController` and `FriendProfilesController` feed the remove dialog `open_trades:` (an integer). `PublicProfilesController` no longer loads it, and the `open_trade_token` locals are gone from the public-profile partials.
- Locales: `friends.remove_dialog.trade` now has plural forms with `zero`, `one` and `other` in both languages (zero is never shown, because the line renders only when the count is positive). Removed `trades.one_at_a_time.*` and `errors.game.trade_already_open`. Added `errors.game.trade_already_sent` with `%{name}`, which `refused` already passes.
- Outside the Code Map: `test/controllers/brother_invitations_controller_test.rb` ("friends with an open trade link to it") asserted the public-profile link to the trade, so it now asserts the new-draft link.
- Tests: rewrote the one-per-pair tests listed in the plan. Added operation tests for each I/O matrix row (second trade, opposite trade, identical resend including string keys, empty offer against empty offer, identical but expired, identical from the other side, closed trade does not block), a concurrency race of two identical proposals (one success, one `trade_already_sent`), friends/friend-profile dialog tests for a count of 2 in fr and en, a remove-friend test with two trades in which both are cancelled and every reservation is released, and a system test where an identical resend lands back on the draft with the refusal.
- Verification: `bin/rails test` (3812 runs, 0 failures), the system tests in `test/system/trades_test.rb` and `test/system/friends_test.rb` (25 runs, 0 failures), packwerk, zeitwerk, i18n-tasks missing/unused, rubocop, brakeman, `script/check_planning_references`, `script/check_file_sizes` all pass. No TypeScript or CSS was touched.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Resending the terms of a trade past its expiry but not yet swept returns `insufficient_copies` instead of opening a new trade when the old offer holds all the player's copies, and no test covers that case — real, but it lasts at most until `Game::ExpireTradesJob` runs (about a minute after the seven days end), and its only fix is to put back the expiry inside `ProposeTrade`, which AD-8 removes on purpose ("neither checks nor expires a pair's trades"); the matrix row holds whenever spare copies remain, and the operation test asserts the brief refusal.

## Design Notes

The identical check reads candidates first (`pluck(:id)` of the pair's unexpired open trades by this proposer), then one `TradeItem.where(trade_id:)` load grouped by trade and side, and compares with the normalised hashes; the two bank locks already serialise concurrent proposals between the pair, so no constraint is needed. The refusal copy, not designed in EXPERIENCE.md: en "You already sent this proposal to %{name}.", fr "Vous avez déjà envoyé cette proposition à %{name}." (check how `Game::Operation.failure_message` passes `name:`).

## Verification

**Commands:**
- `bin/rails test test/domains/game test/controllers/trades_controller_test.rb test/controllers/friends_controller_test.rb test/controllers/friend_profiles_controller_test.rb test/controllers/public_profiles_controller_test.rb` -- expected: pass
- `bin/rails test test/system/trades_test.rb test/system/friends_test.rb` -- expected: pass
- `bin/rails test` -- expected: pass
- `bundle exec packwerk check && bin/rails zeitwerk:check && bundle exec i18n-tasks missing && bundle exec i18n-tasks unused && bin/rubocop` -- expected: pass
- `script/check_planning_references && script/check_file_sizes` -- expected: pass
- `git diff --stat db/schema.rb` -- expected: only the index line removed and the version bumped

## Auto Run Result

- **Summary:** two friends may hold any number of open trades; `Game::ProposeTrade` refuses only a proposal identical to one the same player has open and unexpired with that friend (`trade_already_sent`); every trade button opens the friend's new-proposal draft; the remove-friend dialog counts the open trades it cancels.
- **Files changed:**
  - `db/migrate/20261101100000_remove_game_trades_one_open_per_pair_index.rb` -- drops the per-pair partial unique index concurrently, reversible.
  - `db/schema.rb` -- regenerated from the migrations: the index line and the version only.
  - `app/domains/game/app/operations/game/propose_trade.rb` -- per-pair check, duplicate-key rescue and pre-expiry removed; identical-proposal refusal added after the bank locks.
  - `app/domains/game/app/queries/game/open_trade_counts_by_friend.rb` -- replaces `open_trades_by_friend.rb`: open trades counted per friend.
  - `app/controllers/{trades,friends,friend_profiles,public_profiles}_controller.rb` -- the new-trade redirect and the open-trade token lookups removed; counts passed to the dialogs.
  - `app/views/friends/{show,_friend_row,_remove_dialog}.html.erb`, `app/views/friend_profiles/show.html.erb`, `app/views/public_profiles/{show,_profile,_summary,_action}.html.erb` -- trade buttons link to the draft; the dialog takes a count.
  - `config/locales/{en,fr}.yml` -- `trade_already_sent` added, `trade_already_open` and `trades.one_at_a_time` removed, `friends.remove_dialog.trade` pluralised with `zero`.
  - Tests in `test/domains/game`, `test/controllers` and `test/system` rewritten for the new rule, plus one operation test per matrix row, a race of identical proposals and a removal with two trades.
- **Review findings:** 0 patched, 0 deferred, 1 rejected (low: the brief `insufficient_copies` after an unswept expiry, the cost AD-8 accepts).
- **Follow-up review recommendation:** false (no patch applied).
- **Verification:** full `bin/rails test` 3812 runs, 0 failures (implementer); rerun here: domain and touched controller tests 963 runs, 0 failures; `test/system/trades_test.rb` and `test/system/friends_test.rb` 25 runs, 0 failures; packwerk, zeitwerk, i18n-tasks missing and unused, rubocop, `script/check_planning_references` and `script/check_file_sizes` pass; schema rebuilt from migrations matches. No TypeScript or CSS changed.
- **Residual risks:** for up to a minute after a trade's seven days end and before the sweep, its offered copies stay reserved, so a new proposal reusing them is refused as insufficient; the copy of the `trade_already_sent` refusal and of the plural removal line is not yet in the UX copy deck.
