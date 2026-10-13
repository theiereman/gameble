---
title: 'A player removes a friend'
type: 'feature'
ticket: '42'
created: '2026-10-13'
status: 'built'
baseline_revision: '4ab2658436ebb8e6c5d74a166e473bef90cd75b7'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nothing ends a friendship, so one made by mistake, or by a hostile page sending a signed-in player to an invite link (the deferred finding of the invite link story), lasts for ever.

**Approach:** Each friend row on the Friends screen gets "RETIRER" / "REMOVE" beside "ÉCHANGE", opening a confirmation dialog; confirming POSTs to a new `friends#remove`, which calls one operation `Game::RemoveFriend`. In one transaction it cancels the open trade between the two players and releases its reserved copies by reusing `Game::CancelOpenTrades` (narrowed to that partner), deletes the friendship row, and publishes one `Game::FriendRemoved` event. `PlayerStream` turns it into silent refresh signals for both players (friends, plus trades when a trade was cancelled), never the new-friend toast. Either player may invite the other again through the existing invitation flow.

**Decisions (author, 2026-10-13):** the open trade is cancelled and its cards released; the removal is silent; the action sits on the friend row, behind a confirmation step. Assumption from the entry: the friend-only parts of the former friend's profile close as for any non-friend, and the feed's Friends tab follows the friendship (both already read `Game::Friendship` at request time).

## Boundaries & Constraints

**Always:** writes only through `Game::RemoveFriend` (named `Pack::VerbNoun`, `Success`/`Failure(:code)`); one event published inside its transaction; the action is a POST with a Pundit policy (`FriendPolicy#remove?`); the URL and DOM carry the friend's token, never an id; bank locks of both players taken in ascending id order (`TradeLocks.players`) before any write; every string in `en.yml` and `fr.yml`; live updates only through `PlayerStream`'s after-commit batch job.

**Never:** a write from a GET; a message, toast or flash to the former friend; a new event per cancelled trade (handlers never publish, and `CancelOpenTrades` publishes none); duplicating the release logic of `CancelOpenTrades`; deleting the pair's old (accepted) invitations; a migration; a system test.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Remove a friend | POST `/fr/friends/<sam token>/remove`, friends | Friendship gone for both; redirect to Friends (303) with toast "Ami retiré" / "Sam ne fait plus partie de vos amis."; Sam's row gone | No error expected |
| Open trade between them | trade open, either side proposed | Trade `cancelled` with `closed_at`, proposer's reserved copies back to free; trades with other players untouched; event carries the trade id | — |
| Expired-but-open trade between them | `expires_at` past, status open | Cancelled too (CancelOpenTrades takes every in-progress trade) | — |
| Former friend | live stream | Notices `{topic: "friends"}` (and `"trades"` when a trade was cancelled) for both, no `friend_id`, so no toast | — |
| Not a friend / unknown token | POST for a non-friend or unknown token | Nothing changes; redirect to Friends with an alert toast "Ce joueur ne fait pas partie de vos amis." | `Failure(:not_a_friend)` |
| Signed out | POST | Refused by the policy (redirect to hub with sign-in alert) | Pundit refusal |
| Re-invitation | after removal | `Game::SendInvitation` by code or link succeeds, acceptance makes them friends again | — |
| Cancel the confirmation | "ANNULER" / "✕" / Esc | Dialog closes, no request sent | — |
| Private friend or private self | trades-closed line on the row | "RETIRER" still shown after the line | — |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/cancel_open_trades.rb` -- `call(player:)` cancels every open trade of a player, locking partners, releasing offers, no event. Add an optional `partner: nil` keyword that narrows `open_trades` to trades between the two; the rest is reused as is. Its callers (`DropFriendsAndTrades`, `Handlers::VisibilityChanged`) keep calling without it.
- `packs/game/app/operations/game/accept_invitation.rb` / `cancel_invitation.rb` -- shape to follow: `require_player`, a pre-check outside the transaction, `TradeLocks.players(a, b)`, re-check under lock, `publish(..., stream_name: stream_name(player.id))`.
- `packs/game/app/models/game/friendship.rb` -- pair stored as `low_player_id < high_player_id`, unique.
- `packs/game/app/queries/game/friendship_between.rb` -- friendship test (false for nil or self).
- `packs/game/app/events/game/invitation_cancelled.rb` -- event class style.
- `app/models/player_stream.rb` -- `notices(event)`; `EVENTS` is what `config/initializers/event_store.rb` subscribes; a `friend_id` in a notice makes `PlayerStreamJob` render the new-friend toast, so the removal's notices must not carry one.
- `app/controllers/friends_controller.rb`, `app/policies/friend_policy.rb`, `config/routes.rb:71-75` -- the Friends screen; routes use the 24-char token constraint `/[1-9A-HJ-NP-Za-km-z]{24}/`.
- `app/controllers/invitations_controller.rb` -- `rate_limit` and redirect-with-flash pattern; `app/controllers/trades_controller.rb:202-217` -- toast flash (`flash[:toast_title]` + `:notice` / `:alert`).
- `app/views/friends/show.html.erb` -- the friend row (`.friends__actions`) and the per-friend profile dialogs rendered after the list; `app/views/friends/_profile_dialog.html.erb` and `app/views/settings/_private_dialog.html.erb` -- the modal markup to copy (native `<dialog>`, `data-controller="dialog"`, close button, form with `data: { turbo: false }`, primary confirm + secondary cancel with `data-action="dialog#close"`).
- `app/components/button_component.rb` -- `opens:` renders a dialog-opener button with `aria-haspopup="dialog"`; `app/helpers/friends_helper.rb` -- `friend_dialog_id(token)`, `friend_name(player)`.
- `app/frontend/styles/settings.css:143-160` (`.private-dialog__*`) -- dialog form layout to mirror in `app/frontend/styles/friends.css`.
- Accounts lookup by token: `Accounts::PlayerByToken.call(token)` (nil when unknown).
- Tests to imitate: `test/packs/game/drop_friends_and_trades_test.rb` (holdings, `propose`, reserved asserts), `test/models/player_stream_test.rb` (notices), `test/controllers/friends_controller_test.rb` (`SteamSignIn#sign_in`, row assertions), `test/packs/game/invitation_test.rb` (send/accept).

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/operations/game/cancel_open_trades.rb` -- add `partner: nil`; with a partner, `open_trades` keeps only trades whose proposer/recipient pair is the two players -- reuse, not duplicate, the release.
- [x] `packs/game/app/events/game/friend_removed.rb` -- `Game::FriendRemoved` event, data `{ player_id:, friend_id:, trade_ids: [] }`.
- [x] `packs/game/app/operations/game/remove_friend.rb` -- `Game::RemoveFriend#call(player:, friend:)`: `require_player`; `Failure(:not_a_friend)` unless `friend` is a persisted `Accounts::Player` and `FriendshipBetween`; in `transaction`: `TradeLocks.players`, re-check the friendship under lock (`Failure(:not_a_friend)`), `step CancelOpenTrades.new.call(player:, partner: friend)`, delete the pair's `Friendship` row, publish `FriendRemoved` with the cancelled trade ids on `stream_name(player.id)`; returns the friend.
- [x] `app/models/player_stream.rb` -- add `Game::FriendRemoved` to `EVENTS` (a friendship events list); notices: `friends` for both, plus `trades` for both when `trade_ids` is not empty; no `friend_id`.
- [x] `config/routes.rb` -- `post "friends/:token/remove" => "friends#remove", as: :remove_friend` with the token constraint, placed with the friends routes.
- [x] `app/policies/friend_policy.rb` -- `remove? = player?`.
- [x] `app/controllers/friends_controller.rb` -- `remove`: authorize, `Game::RemoveFriend.new.call(player: current_player, friend: Accounts::PlayerByToken.call(params[:token]))`; success: toast title `friends.removed.title`, notice `friends.removed.text` with the name; failure: `flash[:alert] = Game::RemoveFriend.failure_message(code)`; redirect to `friends_path`, 303; `rate_limit` like `InvitationsController` (only `:remove`).
- [x] `app/views/friends/show.html.erb` -- after the ÉCHANGE button or trades-closed line, a small secondary `ButtonComponent` "Retirer" with `opens: remove_friend_dialog_id(token)` and aria label "Retirer Sam de vos amis"; render one `friends/remove_dialog` per friend beside the profile dialogs, passing whether an open trade exists (`@open_trade_tokens.key?(id)`).
- [x] `app/helpers/friends_helper.rb` -- `remove_friend_dialog_id(token) = "remove-friend-#{token}"`.
- [x] `app/views/friends/_remove_dialog.html.erb` -- modal like the private dialog: title, text (who leaves whose list, no message sent, either can invite again), the trade line when a trade is open, a POST form to `remove_friend_path(token:)` with primary "Retirer" and secondary "Annuler" (`dialog#close`), `aria-labelledby`/`aria-describedby` on ids built from the token.
- [x] `app/frontend/styles/friends.css` -- `.remove-friend-dialog__form/__text/__actions` mirroring `.private-dialog__*`.
- [x] `config/locales/fr.yml`, `config/locales/en.yml` -- `friends.show.remove`, `friends.show.remove_friend` (with name), `friends.remove_dialog.{title,text,trade,confirm,cancel,close}`, `friends.removed.{title,text}`, `errors.game.not_a_friend`.
- [x] `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`, `DESIGN.md` -- the friend row's "RETIRER" and its confirmation copy, so the docs match the screen.
- [x] `test/packs/game/remove_friend_test.rb` -- friendship gone both ways; open trade between them cancelled with reservations released, whichever side proposed; a trade with a third player untouched; one `FriendRemoved` event with the trade ids; not a friend / nil friend / self → `:not_a_friend`, nothing changed; signed-out or banned actor → `:player_required`; re-invitation by code then acceptance makes them friends again.
- [x] `test/models/player_stream_test.rb` -- `FriendRemoved` notices: friends for both without `friend_id`; trades for both only when trades were cancelled.
- [x] `test/controllers/friends_controller_test.rb` -- row shows "Retirer" opening the dialog by token; dialog posts to the token path and mentions the trade only when one is open; GET writes nothing; POST removes for both (the former friend's Friends page no longer lists the player), shows the toast, cancels the open trade and frees its copies; the job enqueued for the former friend carries no `friend_id`; a non-friend POST changes nothing and alerts; signed-out POST is refused; strings in both locales.

**Acceptance Criteria:**
- Given two friends with an open trade, when one confirms the removal from the Friends screen, then neither lists the other, the trade is cancelled and the proposer's copies are free, and the former friend receives no toast or flash.
- Given a removed friendship, when either player invites the other by code or link and it is accepted, then they are friends again.
- Given the confirmation dialog, when the player cancels it, then no request is sent and the friendship stays.

## Implementation Notes

**Decisions**
- `CancelOpenTrades#call(player:, partner: nil)`: `open_trades(player, partner)` builds the proposed and received scopes and, with a partner, narrows each side to the other player (a plain `where(recipient_id: nil)` would have meant `IS NULL`, so the unfiltered path returns the two scopes untouched). Locking, release and the deadlock retry are unchanged.
- `RemoveFriend` checks the friendship before the transaction (`friend_of`, which also rejects a non-player, an unsaved player, nil and self). Under `TradeLocks.players(player, friend)` it deletes the pair's row first and steps `Failure(:not_a_friend)` when `delete_all` removes nothing (a concurrent removal, or a ban/deletion's `DropFriendsAndTrades`, which does not take the pair's locks), rolling back; only then does it cancel the trades. It leaves invitations alone, and publishes one `FriendRemoved` carrying `trade_ids` of the trades `CancelOpenTrades` returned.
- `PlayerStream`: new `FRIENDSHIP_EVENTS = [ Game::FriendRemoved ]` folded into `EVENTS` (so the existing `event_store.subscribe(PlayerStream, to: PlayerStream::EVENTS)` picks it up with no initializer change); notices are `friends` for both, then `trades` for both when `trade_ids` is not empty; no `friend_id`.
- The controller's rate limit (20 a minute) has its own message `friends.throttled`.
- Dialog copy names the friend in the title ("Retirer Sam ?" / "Remove Sam?"); the text and the trade line sit in one `div` that `aria-describedby` points to, so the trade warning is read with the text. The trade line shows when `@open_trade_tokens` has the friend, i.e. an unexpired open trade; an expired-but-open trade is still cancelled by the operation, just not announced in the dialog.
- The trade line is styled in `--color-accent` (blue), noted in DESIGN.md.

**Files touched**
- `packs/game/app/operations/game/cancel_open_trades.rb`, `packs/game/app/operations/game/remove_friend.rb` (new), `packs/game/app/events/game/friend_removed.rb` (new)
- `app/models/player_stream.rb`, `app/controllers/friends_controller.rb`, `app/policies/friend_policy.rb`, `config/routes.rb`, `app/helpers/friends_helper.rb`
- `app/views/friends/show.html.erb`, `app/views/friends/_remove_dialog.html.erb` (new), `app/frontend/styles/friends.css`
- `config/locales/en.yml`, `config/locales/fr.yml`
- `test/packs/game/trade_concurrency_test.rb` (removal races)
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` (friend row rule, "Removing a friend" copy-deck row), `DESIGN.md` (friend row, remove-friend dialog)
- Tests: `test/packs/game/remove_friend_test.rb` (new), `test/models/player_stream_test.rb`, `test/controllers/friends_controller_test.rb`, `test/packs/game/drop_friends_and_trades_test.rb`

**Surprises**
- `drop_friends_and_trades_test.rb`'s `flaky_cancel` stubs the private `lock_open_trades` with a one-argument block; it now takes and forwards `partner`.
- A controller test for the rate limit was added (with `CountingRateLimit`), mirroring the invitations one.
- Cancelling the dialog (no request sent) is browser behaviour of the existing `dialog#close`; with system tests off it is covered only by the markup assertions (cancel is `type=button` with `data-action="dialog#close"`).

**Review fixes**: the delete-first guard above; the race tests in `test/packs/game/trade_concurrency_test.rb` (two removals at once, and one waiting on the other's lock); re-invitation by link; the third-party trade test now removes as the player who also trades with Carol; the controller tests also cover a private viewer's row, the friend profile 404 and the feed's Friends tab for both players after a removal, and Sam's trades notice.

**Verification (2026-10-13)**: `bin/rails test` 2405 runs before the review fixes, 2408 after, 0 failures; `npm run test:js` 243 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` / `unused`, `bin/brakeman` all clean.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 22 findings — high 0, medium 2, low 12, false 8, maybe-false 0
- findings:
  - `[false]` `[reject]` (intent-alignment) A strict "silent" reading would hide every trace from the former friend, yet their list refreshes live and the cancelled trade shows in their history — the entry says the player "simply leaves their list" and the author decided the trade is cancelled; no toast, flash or message reaches them, which is what silent asks.
  - `[low]` `[patch]` (intent-alignment) Re-invitation was proven only by friend code, not by the invite link that motivated the story — test added: after a removal `SendInvitation(recipient_token:)` sends, and acceptance makes them friends again.
  - `[low]` `[patch]` (intent-alignment) The friend profile and the feed's Friends tab closing after a removal were assumed, never tested — controller assertions added for both players: profile 404, Friends tab empty (grouped with the blind hunter's matrix-rows finding).
  - `[low]` `[reject]` (intent-alignment) Cancelling the confirmation is checked only in markup — browser behaviour of the existing `dialog#close`; proving it needs a system test, which AGENTS.md forbids adding for now.
  - `[false]` `[reject]` (intent-alignment) The removal's resistance to a cross-site request is untested — it is a POST behind Rails' default forgery protection (`ActionController::Base`), and the GET is shown to write nothing; no cross-site path reaches it.
  - `[medium]` `[patch]` (verification-gap) The `partner:` filter was untested: the third-party trade never involved the remover, so the test passed without the filter — the test now removes as Alice, who also trades with Carol, and asserts that trade stays open with its reservation and `trade_ids` names only the pair's trade.
  - `[low]` `[patch]` (verification-gap) No race between two removals, so the guard under the lock was unverified — two `LockRaces` tests in `trade_concurrency_test.rb` (crossing removals at once, and one waiting on the other's lock): one Success, one `:not_a_friend`, one `FriendRemoved`.
  - `[low]` `[reject]` (edge-case) The dialog omits the trade line for a trade past `expires_at` but not yet closed, which the removal still cancels — only between expiry and the expiry job's next run, when the trade is already over for both players; matching it needs a second query for the dialog.
  - `[false]` `[reject]` (edge-case) `FriendRemoved` without `trade_ids` would raise in `PlayerStream` — the only publisher, `RemoveFriend`, always sets it.
  - `[false]` `[reject]` (edge-case) `CancelOpenTrades` with an unsaved or non-player partner — the only caller passes a friend already checked as a persisted player in a friendship.
  - `[false]` `[reject]` (edge-case) A malformed token gets a 404, not the alert — the matrix's "unknown token" is a well-formed one, which is tested; every token route in the app uses the same constraint.
  - `[medium]` `[patch]` (blind) Same as the verification-gap finding on the `partner:` filter — same fix.
  - `[low]` `[patch]` (blind) Same as the verification-gap race finding — same fix.
  - `[low]` `[patch]` (blind) The re-check under lock was a read; a friend's ban or deletion (`DropFriendsAndTrades`, which does not take the pair's locks) could delete the row in between and a `FriendRemoved` would still go out — `RemoveFriend` now deletes the row first under the lock and fails with `:not_a_friend`, rolling back, when nothing was deleted.
  - `[false]` `[reject]` (blind) The `partner:` keyword clashes with "partner" in the comment above `lock_open_trades` — both mean the other party of a trade; no caller or rule diverges.
  - `[low]` `[reject]` (blind) The former friend gets no `trades` signal when no trade was open, so a draft left open for the remover only learns on submit — the submit already refuses with "You can only trade with a friend."; a live refresh would also wipe a draft in progress.
  - `[low]` `[reject]` (blind) The dialog and the operation disagree on an expired-but-open trade — same as the edge-case finding, same reason.
  - `[low]` `[patch]` (blind) Matrix rows untested: a private viewer's row, and the profile and feed after a removal — tests added (private viewer's row still offers "Retirer"; profile and Friends tab for both players).
  - `[low]` `[patch]` (blind) The rate-limit message borrowed `invitations.throttled` — new `friends.throttled` in both locales, checked by the rate-limit test.
  - `[false]` `[reject]` (blind) `not_a_friend` is one letter from `not_friends` — they belong to different operations and each message is pinned by its own tests (`remove_friend_test.rb` checks the removal refusal in both languages).
  - `[low]` `[patch]` (blind) The controller removal test did not check the former friend's `trades` notice — assertion added.
  - `[false]` `[reject]` (blind) The plan lists lenses but no triage — the triage log is written once every lens has reported, which is this entry.

## Design Notes

The removal mirrors `DropFriendsAndTrades` for one pair: cancel the trades first (they need the friendship to be a fair close), then drop the friendship row. `CancelOpenTrades` already locks every trade party in order, releases offers and writes no event, so `RemoveFriend` publishing a single `FriendRemoved` keeps "one event per operation" and the event carries the cancelled trade ids so `PlayerStream` knows to refresh the trade badges. Old `accepted` invitations stay: the pending-only unique index lets a new invitation through.

Confirm button: primary, as in the private dialog (DESIGN.md keeps the danger button for account deletion only).

## Verification

**Commands:**
- `bin/rails test` -- expected: 0 failures (system tests skipped)
- `npm run test:js`, `npm run typecheck` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing` -- expected: clean

## Auto Run Result

**Summary:** Each friend row on the Friends screen has "RETIRER" / "REMOVE" after "ÉCHANGE" (or the trades-closed line), opening a confirmation dialog; confirming POSTs to `friends#remove` (`POST /:locale/friends/:token/remove`, `FriendPolicy#remove?`, 20 a minute). `Game::RemoveFriend` locks both players, deletes the friendship row (failing with `:not_a_friend`, rolled back, when none is left), cancels the open trades between them and releases their reserved copies through `Game::CancelOpenTrades` narrowed with `partner:`, and publishes one `Game::FriendRemoved`. `PlayerStream` refreshes both players' friends (and trades when a trade was cancelled) without the new-friend toast; the remover gets an "Ami retiré" toast, the former friend nothing. Either can invite the other again; the friend profile and the feed's Friends tab follow the friendship.

**Files changed:**
- `packs/game/app/operations/game/remove_friend.rb` (new) -- the removal operation.
- `packs/game/app/events/game/friend_removed.rb` (new) -- its event, `{ player_id, friend_id, trade_ids }`.
- `packs/game/app/operations/game/cancel_open_trades.rb` -- optional `partner:` narrowing to the pair's trades.
- `app/models/player_stream.rb` -- silent refresh notices for `FriendRemoved`.
- `app/controllers/friends_controller.rb`, `app/policies/friend_policy.rb`, `config/routes.rb` -- the POST action, its policy and route.
- `app/views/friends/show.html.erb`, `app/views/friends/_remove_dialog.html.erb` (new), `app/helpers/friends_helper.rb`, `app/frontend/styles/friends.css` -- the row button and the confirmation dialog.
- `config/locales/en.yml`, `config/locales/fr.yml` -- row, dialog, toast, throttle and `errors.game.not_a_friend` strings.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md`, `DESIGN.md` -- the friend row's "RETIRER", the dialog and its copy.
- `test/packs/game/remove_friend_test.rb` (new), `test/packs/game/trade_concurrency_test.rb`, `test/models/player_stream_test.rb`, `test/controllers/friends_controller_test.rb`, `test/packs/game/drop_friends_and_trades_test.rb` -- operation, race, stream and request tests; the existing stub forwards `partner`.
- `_bmad-output/initiative-gameble/deferred-work.md` -- the cross-site invite link entry marked resolved by this ticket.

**Review:** thorough (blind hunter, edge-case hunter, verification gap, intent alignment), 22 findings. Patched 8 entries' findings (medium: the `partner:` filter untested; low: race tests, delete-first guard, re-invitation by link, profile/feed/private-viewer tests, own throttle key, former friend's trades notice). Deferred none. Rejected 4 low (cancel step needs a system test; expired-but-open trade not announced in the dialog, twice; no trades signal for a draft page without a trade) and 8 false, each with its reason in the triage log.

**Follow-up review recommended:** false -- patched entries by verdict: high 0, medium 1, low 6.

**Verification:** `bin/rails test` 2408 runs, 0 failures (system tests skipped); `npm run test:js` 243 passed; `npm run typecheck` clean; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 701 files, no offenses; `bundle exec i18n-tasks missing` and `unused` clean. No migration.

**Residual risks:** the dialog's open/cancel behaviour has not run in a real browser (system tests disabled); a trade past its expiry but not yet closed by the expiry job is cancelled without being announced in the dialog.
