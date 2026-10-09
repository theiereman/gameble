---
title: 'A private profile closes its social side'
type: 'feature'
ticket: '20'
created: '2026-10-09'
status: done
baseline_revision: 'a3230dcdfb0565a540d1b9c76abe84b81129ebc7'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/change-profile-privacy/change-profile-privacy.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A private profile hides the collection from friends, but the rest of the social side stays open:
- a private player still shows online, with their activity, and counts in "n en ligne";
- they can propose, counter and accept trades, and receive proposals;
- going private leaves their open trades running.

The author's rule (change-profile-privacy, 2026-10-09):
- a private player keeps their friendships;
- friends see nothing beyond the friendship;
- nobody trades with a private player in either direction;
- going private cancels their open trades, after a confirmation.

**Approach:**
- `Game::Visibility.open_to_friends?` is the one question that trades and presence ask.
- Going private publishes `Accounts::VisibilityChanged`, and a Game handler cancels the player's open trades under the lock order; `PlayerStream` tells the partners.
- Presence shows "Profil privé".
- The trades screen and the friend profile show a "trades closed" line that names whose profile it is.

## Boundaries & Constraints

**Always:**
- Friends only behaves exactly as today.
- Writes go through operations; an operation publishes one event in its transaction; handlers run in it and never publish; broadcasts go through the after-commit job.
- Bank locks are taken in ascending player id before any trade or holding row.
- The privacy check inside a trade operation reads each player's visibility as it stands under the lock, not from an object loaded before it.
- Every string is in `en.yml` and `fr.yml`.
- Database ids stay out of the HTML.
- A GET never writes.
- No planning ids in code or tests.

**Never:**
- No migration.
- No change to `Game::Visibility.visible?` semantics or to the feed.
- Cancel, decline and expiry stay open to a private player, so they can still close what is theirs.
- The friend row's trade button belongs to story 21.
- Going public again restores nothing.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Going private with trades open | A has 2 open trades (one as proposer, one as recipient) and sets PRIVÉ | Both trades `cancelled`; every reserved copy released; both partners get a live trades notice | — |
| Confirmation | A has open trades and opens settings | PRIVÉ opens a dialog: "Passer en privé annule vos 2 échanges en cours." with PASSER EN PRIVÉ / ANNULER; with no trade open, PRIVÉ applies at once | Without JS, the PATCH still cancels server-side |
| Going friends only or public | A sets AMIS UNIQUEMENT or PUBLIC | No trade touched | — |
| Private proposes | Private A proposes to friend B | Refused; nothing reserved | `Failure(:own_profile_private)` with "Votre profil est privé : les échanges sont fermés." |
| Proposing to private | A proposes to private friend B, by the screen or a forged POST | Refused | `Failure(:friend_profile_private)` with "Le profil de B est privé : échanges fermés." |
| Counter or accept with a private party | Either party became private (trade still open by a race) | Refused, nothing moves | The same two codes |
| Draft for a private friend | GET `/trades/new?friend=<private B>` | Refusal toast naming B, redirect to the trades list | — |
| Closed trade board | The friend or the viewer is private | The trades-closed line replaces NOUVEL ÉCHANGE | — |
| Friend profile while private | Private A opens friend B's profile | Showcase shown; the trades-closed line replaces PROPOSER UN ÉCHANGE | — |
| Presence | B is private | B's row reads "Profil privé"; B is left out of "n en ligne" and the hub count | — |
| Friends only | B is friends-only | Presence and trades as today | — |
| Race | B proposes to A while A goes private | Either the proposal commits first and A's change cancels it, or A's change commits first and the proposal is refused | No reservation left behind |

</frozen-after-approval>

## Code Map

**Visibility and trades**

- `packs/game/app/models/game/visibility.rb`: add `self.open_to_friends?(player)`, which is `player && !player.removed? && !player.visibility_private?`. Leave `visible?` alone. Test: `test/packs/game/visibility_test.rb`, using `visibility_private!`.
- `packs/accounts/app/models/accounts/player.rb:37-38`: the visibility enum, with `prefix: :visibility`.
- `packs/game/app/operations/game/trade_steps.rb:22-24` (`friends`):
  - after the friendship check, re-read both players' visibility under the lock (`Accounts::Player.where(id:).pick(:visibility)`, or a reload);
  - return `Failure(:own_profile_private)` for the acting player and `Failure(:friend_profile_private)` for the other.
  - Callers: `propose_trade.rb:15`, `counter_trade.rb:20`, `accept_trade.rb:17`, all after `TradeLocks`. Close, cancel and expire do not call it.
- `lib/application_operation.rb:30-35`: `failure_message(code)` passes no interpolation. Add `**options` through to `I18n.t`.
- `app/controllers/trades_controller.rb`:
  - `refused(code)` (193-195) passes `name: helpers.friend_name(friend)` where a friend is known.
  - `tradable?` (126-128) also asks `open_to_friends?` for `current_player` and the friend.
  - `new` (22-33): a friend who is a friend but not tradable because of privacy gets the refusal toast and a redirect to the list, as `new:27` does for "one at a time". A non-friend still gets 404.
  - `load_board` (146): when the board is not tradable because of privacy, set the reason for the view.
- `app/views/trades/_board.html.erb:61-62`: the trades-closed line, with the `RÉGLAGES` link when it is the viewer's own profile, in place of `trades.actions.again`.
- `app/views/friend_profiles/show.html.erb:25`: the trades-closed line (own) in place of PROPOSER UN ÉCHANGE when `current_player` is private. A private friend already gets `unavailable` (`friend_profiles_controller.rb:9`).
- Locales: `errors.game` (en around line 1047, fr around 1070); the trades-closed lines next to `trades.actions.again` (en 761, fr 780).

**Presence**

- `packs/game/app/queries/game/friends_presence.rb`:
  - `row` (34-43) gives `state: :private` for a private friend, with no activity or seen time;
  - `online_count` (23-32) adds `.where.not(visibility: "private")`.
- `app/helpers/presence_helper.rb:2-8`: a `:private` branch reading `friends.show.presence.private` ("Profil privé"). `app/views/friends/_presence.html.erb` gets the modifier class `friends__presence--private`; give it the muted style in `app/frontend/styles/friends.css`.
- The hub count is `pages_controller.rb:17`, through `online_count`.

**Going private**

- `packs/accounts/app/events/accounts/visibility_changed.rb`: new, the same shape as `player_banned.rb`, with data `{ player_id:, visibility: }`.
- `packs/accounts/app/operations/accounts/set_visibility.rb`:
  - in the transaction, publish `VisibilityChanged` (stream `"Accounts::Player$#{id}"`) **before** `update!`, the order `DeletePlayer` uses so the Game handler takes bank locks before the player row is written;
  - update the header comment, which says it publishes nothing.
- `packs/game/app/operations/game/cancel_open_trades.rb`: new, `call(player:)`, using `require_account`. Extract the trade part of `drop_friends_and_trades.rb` (`open_trades` 21-23, `lock_open_trades` 26-36, `release_offers` 38-45, the `update_all` at 12) into it, and make `DropFriendsAndTrades` call it with `step`.
  - Lock sequence: read the partner ids, `TradeLocks.players` on all ids sorted in one call, re-read, lock any newcomer, then `open_trades.order(:id).lock`, release the offers, cancel.
  - Behaviour of `DropFriendsAndTrades` is unchanged.
- `packs/game/app/handlers/game/handlers/visibility_changed.rb`: new. When `visibility == "private"`, `PlayerById` → `CancelOpenTrades.new.call(player:).value!`.
- `config/initializers/event_store.rb:12-15`: subscribe `PlayerStream` to `Accounts::VisibilityChanged` **before** `Game::Handlers::VisibilityChanged`, since PlayerStream reads the partners before the cancel.
- `app/models/player_stream.rb`: a `VisibilityChanged` branch (private only) that queues the trades notice (`counterparts_notices` 50-56, trade partners only) for every open trade's partner.
- Packwerk: Accounts depends on `lib` only, so the handler and the query live in Game.

**Settings**

- `app/controllers/settings_controller.rb`: `show` (7-11) reads `@open_trades = Game::OpenTradeCount.call(current_player)`. This is a new query in `packs/game/app/queries/game/`: in-progress trades where the player is proposer or recipient.
- `app/views/settings/show.html.erb:32-42`: the radio form of submit buttons (`name="visibility"`). When `@open_trades > 0` and the player is not private, PRIVÉ is `ButtonComponent.new(opens: "private-dialog")`, and a dialog copied from `app/views/trades/_undo_dialog.html.erb` holds its own PATCH form with hidden `visibility=private`. Update the header comment (9-17).
- Locales: `settings.show.visibility.*` (fr 578, en 560).

**Tests to extend**

- `test/packs/game/visibility_test.rb`, `trade_test.rb` (around line 53), `trade_accept_counter_expire_test.rb` (copy the banned test at line 147), `drop_friends_and_trades_test.rb` (must stay green), `friends_presence_test.rb` (copy line 83).
- `test/packs/accounts/set_visibility_test.rb`, `test/models/player_stream_test.rb:104-140`, and a concurrency case in `trade_concurrency_test.rb`.
- `test/controllers/trades_controller_test.rb` (237, 464), `friend_profiles_controller_test.rb`, `friends_controller_test.rb:52`, `settings_controller_test.rb`.
- `test/system/settings_test.rb` (the confirmation) and `test/system/trades_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `visibility.rb`, `trade_steps.rb`, `application_operation.rb`, locales -- `open_to_friends?`, the two refusal codes read under the lock, interpolated messages -- one gate for trades
- [x] `trades_controller.rb`, `_board.html.erb`, `friend_profiles/show.html.erb`, locales -- tradable asks the gate; new redirects with a named refusal; the trades-closed line -- the screens say why
- [x] `friends_presence.rb`, `presence_helper.rb`, `_presence.html.erb`, `friends.css`, locales -- "Profil privé", left out of online counts -- presence follows the rule
- [x] `visibility_changed.rb` (event), `set_visibility.rb`, `cancel_open_trades.rb`, `drop_friends_and_trades.rb`, `handlers/visibility_changed.rb`, `event_store.rb`, `player_stream.rb` -- going private cancels trades under the lock order and tells partners -- no promise survives going private
- [x] `open_trade_count.rb`, `settings_controller.rb`, `settings/show.html.erb`, locales -- confirm before going private -- the cancellation is not reversible
- [x] Tests -- one per matrix row, plus `drop_friends_and_trades_test.rb` kept green -- protect the rule

**Acceptance Criteria:**
- Given a friends-only friend, when trading and viewing presence, then everything behaves as before this story.
- Given the full suite, when run, then `drop_friends_and_trades_test.rb` and the deletion and ban tests pass unchanged.

## Implementation Notes

- **The gate.** `Game::Visibility.open_to_friends?` is asked by `TradeSteps#friends` (after the friendship check, on players re-read with `Accounts::Player.where(id:)` under the bank locks), by `TradesController#privacy_refusal`, by the friend profile and by `FriendsPresence.row`. `ApplicationOperation.failure_message(code, **values)` passes interpolations through.
- **Controller.** `tradable_friend` is now `befriended` (friendship and standing only); `privacy_refusal(friend)` returns `:own_profile_private`, `:friend_profile_private` or nil. `new` and `create` refuse a private party with the named toast and go to the list; a non-friend still gets 404 on `new` and `:not_friends` on `create`. Every `refused` call passes the friend, so the message can name them.
- **The trades-closed line reuses the refusal messages** (`errors.game.own_profile_private` / `friend_profile_private`) through `TradesHelper#trades_closed_line`, rather than adding a second copy of the same text next to `trades.actions.again`. Only the link label `trades.closed.settings` ("RÉGLAGES" / "SETTINGS") is new. The line replaces NOUVEL ÉCHANGE on a closed board and PROPOSER UN ÉCHANGE on the friend profile when the viewer is private.
- **Presence.** A private friend's row is `state: :private`, with no activity or seen time; `Row#online?` now means `:online` or `:active` (it was `!= :offline`, which would have counted `:private`). `online_count` leaves private friends out. The `friends__presence--private` modifier is muted and hides the dot.
- **Going private.** `Accounts::SetVisibility` publishes `Accounts::VisibilityChanged` (`{ player_id:, visibility: }`) on every change, before `update!`; only `"private"` has an effect. `Game::CancelOpenTrades` is the trade half of `DropFriendsAndTrades`, moved as it was (its lock sequence already matched the plan: all ids sorted in one `TradeLocks.players` call, then newcomers); `DropFriendsAndTrades` calls it through `step`. `PlayerStream` is subscribed to `PRIVACY_EVENTS` before `Game::Handlers::VisibilityChanged` and sends the trades notice to trade partners only.
- **Settings confirmation: a deviation from the code map.** PRIVÉ stays a `segmented__option` submit button and gains the `dialog-opener` data attributes, instead of becoming `ButtonComponent.new(opens:)`. `dialog_opener_controller` calls `preventDefault` when the dialog exists, so with JavaScript the click opens `settings/_private_dialog` (its own PATCH form with hidden `visibility=private`); without JavaScript the button still submits and the server cancels. A `ButtonComponent` would have broken the segmented styling and done nothing without JavaScript. The dialog title ("Passer en privé ?" / "Go private?") and the close label are additions to the copy deck.
- **Tests added.** Visibility gate; propose refused both ways, the stale-object case, friends only unchanged; accept and counter refused with a private party while cancel, decline and expire still work; presence and online count; the event and the cancellation in `set_visibility_test`; partner notices in `player_stream_test`; three concurrency cases (proposal committed first, then cancelled; going private first, then refused; a three-way race); controller tests for the draft redirect, the forged POST, the closed board, the friend profile, the friends page and menu 04, and the settings dialog; system tests for the confirmation, the draft redirect and the partner's live board.
- **After review.**
  - `SetVisibility` now locks the player row FOR NO KEY UPDATE first, as `BanPlayer` and `DeletePlayer` do, then publishes, then writes the row. Setting the visibility the player already has publishes nothing.
  - On going private, `PlayerStream` also sends a trades notice to the player themself, so their other tabs refresh.
  - `TradeSteps#friends` checks removal on the rows re-read under the lock, so a friend banned meanwhile gets `:not_friends`.
  - `load_board` computes the privacy refusal once and derives `@trade_again` from it; `tradable?` is gone.
- **Known limits.**
  - `PlayerStream` reads the partners before the handler takes the bank locks. A proposal that commits between that read and the lock is cancelled, but its proposer gets no live notice; they see it on the next load.
  - Players who went private before this change may still have open trades. Accept and counter now refuse those trades; cancel, decline and expiry still close them. Nothing backfills them.

## Plan Change Log

## Review Triage Log

### 2026-10-09: thorough review, pass 1 (blind-hunter, edge-case-hunter, verification-gap, intent-alignment)

Counts: high 0, medium 2, low 13, false 0, maybe-false 0. Routes: 8 patch, 4 defer, the rest rejected.

| Lens | Finding | Verdict | Route | Evidence |
|---|---|---|---|---|
| edge-case | `SetVisibility` takes bank locks (through the handler) before the player row, the inverse of `BanPlayer` and `DeletePlayer`; a ban racing a change to private can deadlock, and the comment claims the deletion's order | medium | patch | `ban_player.rb:32-34` and `delete_player.rb:29-31` lock `FOR NO KEY UPDATE` before publishing; `set_visibility.rb` locks nothing |
| blind | `SetVisibility` publishes when nothing changes, so a repeated PRIVÉ reruns the cancel | low | patch | It publishes on every call; an early return on an unchanged value is a direct correction |
| blind | The `event_store.rb` comment says the `VisibilityChanged` handler drops ties | low | patch | The handler cancels trades only |
| edge-case, blind | The player's own other tabs are not told their trades were cancelled | low | patch | The private branch notifies partners only; a self `trades_notice` is a direct addition |
| blind | `TradeSteps#friends` reads `removed?` from the stale object but visibility fresh, so a partner banned meanwhile is refused as private | low | patch | The fresh rows are already loaded under the lock |
| blind | `load_board` runs the friendship and privacy queries twice for a closed trade | low | patch | `tradable?`, then `befriended?` and `privacy_refusal` again |
| verification-gap, blind | The counter refusal toast is never checked for the friend's name; the `own_profile_private` toast after a forged proposal is unchecked | medium | patch | Pre-verified: reverting `refused(..., trade.friend)` keeps the tests green |
| blind | No test shows a friends-only viewer keeps PROPOSER UN ÉCHANGE on a friend's profile | low | patch | The friend profile change gates on `open_to_friends?` for the viewer |
| edge-case, blind | A trade opened after settings rendered with zero open trades is cancelled with no confirmation, and nothing tells the player afterwards | low | defer | The frozen matrix accepts a server-side cancel without JS; a post-redirect toast ("2 échanges annulés") is new copy |
| blind | The "in-progress trades of a player" query exists three times (`CancelOpenTrades`, `OpenTradeCount`, `Counterparts`) | low | defer | A `Trade` scope adds public surface; for the epic 7 sweep |
| blind | The modal markup is copied a third time, and the settings view hand-copies `ButtonComponent`'s dialog-opener attributes | low | defer | For the epic 7 sweep |
| verification-gap | The `trades_closed` local on the trades list page is untested | low | defer | Pre-verified: only `show` is tested; the lens files it as defer |
| edge-case | A partner whose proposal commits between PlayerStream's read and the handler's lock gets no live notice | low | reject | Needs a proposal within that window; the trade is cancelled correctly and shows on reload |
| edge-case | A newcomer partner is locked out of order and a deadlock aborts the settings PATCH with a 500 | low | reject | The same accepted trade-off as `DropFriendsAndTrades`, which this code moved; it needs a proposal committing inside the cancel |
| edge-case, intent-alignment | Friends with the Friends screen open keep the old presence until reload | low | reject | Presence is read at render by design (AD-13, AD-24); nothing broadcasts it |
| edge-case | A due but unswept trade is counted and recorded as cancelled, not expired | low | reject | Cosmetic; at most one sweep interval |
| blind | `PlayerStream` runs friendship and invitation queries it discards | low | reject | Two small queries per change of visibility |
| blind | `"private"` is compared in two subscribers | low | reject | Two readers of one event field |
| blind | The partner is never told why the trade was cancelled | low | reject | The board shows the trades-closed line while the friend stays private; the plan stores no reason |
| intent-alignment | The friend profile can show only the viewer's own trades-closed line | low | reject | A private friend's profile is "not available" by the approved UX (proposal 8) |
| intent-alignment | `online_count` writes the rule in SQL instead of calling `open_to_friends?` | low | reject | A count needs SQL; the tests pin the two to agree |
| intent-alignment | Past trade boards still show the cards a now-private friend traded | low | reject | They are the viewer's own trades |

## Design Notes

**Publishing before the update.** Publishing `VisibilityChanged` before the `update!` follows `DeletePlayer`. `OpenPack` holds a bank lock and then needs `FOR KEY SHARE` on the player row, so writing the player row before taking bank locks would deadlock against it.

**Reading visibility under the lock.** The trade operations re-read visibility after `TradeLocks`. A proposal that waited on the bank lock behind a commit going private then sees `private` and refuses.

## Verification

**Commands:**
- `bin/rails test test/packs test/controllers test/models` -- expected: 0 failures
- `bin/rails test:system` -- expected: 0 failures
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: green
