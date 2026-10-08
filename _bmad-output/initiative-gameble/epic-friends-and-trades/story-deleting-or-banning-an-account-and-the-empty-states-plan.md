---
title: 'Deleting or banning an account, and the empty states'
type: 'feature'
ticket: '11'
created: '2026-10-07'
status: 'built'
baseline_revision: '9456caaec83deb65db340e76f3ac5648f565aba2'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The card picker's own states ("Aucune carte disponible." with its reason, "n disponibles", "n cartes · n exemplaires (4 cartes au plus)") are not shown, because the picker does not exist yet.
    evidence: |-
      The ticket asks for "the picker's states", but the card picker is the React island of story 5.7, built in a parallel lane and absent at this baseline. Here, "nothing to place" is covered on today's placing surface: the counter form's sides (TradesHelper#trade_nothing_to_place, copy under trades.side.none.*). The island should show the same line and reason for the player's whole collection: none owned, or every copy reserved (Game::FreeCopies against Game::Quantities).
    location: >-
      app/helpers/trades_helper.rb (trade_nothing_to_place); the 5.7 island
    severity: medium
  - summary: >-
      A trade closed by a deletion or a ban reaches the partner only at their next render; no live update or broadcast is sent.
    evidence: |-
      Game::DropFriendsAndTrades runs inside a handler and publishes nothing (AD-10). Story 5.9's private stream and broadcasts are built in a parallel lane. When it merges, it decides how the partner learns of the closing: the stream key is rotated on ban or deletion (AD-13). Its after-commit broadcast jobs must also tolerate invitations and friendships deleted by a later deletion.
    location: >-
      packs/game/app/operations/game/drop_friends_and_trades.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** A deleted or banned player keeps their ties (R6, AD-14): their open trades stay open with the friend's copies reserved, their friendships and invitations stay, and a pending invitation from them can still be accepted (7.8's deferred finding). The Amis and Échanges empty lines do not point to the invite panel, and nothing tells a player why a side has no card to place.

**Approach:** One `Game` operation, `Game::DropFriendsAndTrades`, cancels the player's open trades (both sides' reservations released), deletes their invitations and friendships, and publishes nothing. `Game::ReleasePlayer` runs it first on a deletion, and a new handler runs it on `Accounts::PlayerBanned`, a new event that story 7.5's ban action will publish. A one-off job and rake task sweep the players already deleted or banned (a ban today is `banned_at` set from the console). The screens get their empty states, and the deletion dialog's copy names trades.

**Decisions (autonomous run, author away):**
- A trade closed this way gets the status `cancelled` (no migration). The partner sees it as "CLOS · annulé il y a …" (EXPERIENCE.md: "The trade closes (CLOS) and every reserved copy is released").
- Trade rows and items stay, as the partner's history. Friendships and invitations (any status, both directions) are deleted. A ban drops ties too (epic R6); an unban (7.5) does not restore them.
- No event is published (AD-10: it runs inside a handler), so no live update reaches the partner (5.9). The partner sees the change at the next render.
- "No friend, no trade": one line, with a link to the invite panel (`#friends-invite`).
- "Nothing to place": the picker does not exist yet (story 5.7). The counter form is today's placing surface, so each side of it whose cards have no copy left to place shows "Aucune carte disponible." with its reason: none owned, or all reserved (own side only).
- The dialog note reads "Votre collection, vos boosters, vos échanges en cours et votre profil seront effacés définitivement." (the mock names trades).
- 5.6's guards for a deleted partner's open trade are removed: such a trade no longer exists.

## Boundaries & Constraints

**Always:**
- Writes only through Game operations (AD-3).
- AD-10 lock order: bank locks ascending over the player and every partner of an open trade, then the trade rows, then holdings by ascending proposer and card-season.
- The deletion stays one transaction. A failure rolls it back.
- Invitations are deleted before friendships, so an acceptance in flight either commits first and has its friendship deleted, or finds nothing.
- `0 <= reserved <= quantity` everywhere.
- Copy in fr and en.

**Never:**
- A migration or a new trade status.
- The ban action, the unban, or the stream key (7.5, 5.9).
- The card picker island (5.7).
- Broadcasts.
- Changes to the other trade operations' results.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Delete, recipient of a trade | Alice proposed to Bob (Portal ×2 reserved), Bob deletes | trade `cancelled` with `closed_at`, Alice's Portal `reserved` 0, friendship gone | none |
| Delete, proposer | Bob proposed to Alice, Bob deletes | trade `cancelled`, Bob's rows gone (ReleasePlayer) | none |
| Ban | `Accounts::PlayerBanned` for a banned player | same as delete for trades, friendships and invitations; their holdings stay, unreserved | none |
| Invitations | pending sent and received, accepted ones | all of the player's deleted; others untouched | none |
| Other players | trades and friendships not involving the player | untouched | none |
| Sweep | deleted (before this story) or banned players with ties left | ties dropped, one transaction per player; active players untouched; rerun no-op | a failure is reported and skipped; the rake task aborts with the count left |
| No friend | Amis, no friend | "Aucun ami pour l'instant." with link "Invitez-en un avec votre lien ou votre code." to `#friends-invite` | none |
| No trade | Échanges, no trade | "Aucun échange pour l'instant." with link "Invitez un ami pour échanger des cartes." to `friends#friends-invite` | none |
| Nothing to place | counter form; own side all reserved / none owned; friend owns none | "Aucune carte disponible." + reason on that side | none |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/release_player.rb` -- runs `DropFriendsAndTrades` first (`step`, same transaction, before its own bank lock); update its comment (5.11 is done).
- New `packs/game/app/operations/game/drop_friends_and_trades.rb` -- `< Operation`, `include TradeSteps` (`release` skips missing holdings), `require_record` as in ReleasePlayer. Inside `transaction`:
  - Read the open trades' parties and lock them with `TradeLocks.players`. Re-read until no partner is missing: once the player's own lock is held, no trade op can add a trade, since every trade op takes both bank locks.
  - `Trade.in_progress.…lock`.
  - Sum the offers per proposer, then `TradeLocks.holdings(proposer, ids)` in ascending proposer order, then `release`.
  - `update_all(status: "cancelled", closed_at:, updated_at:)`.
  - `Invitation` sender-or-recipient `delete_all`, then `Friendship.of(id).delete_all`.
- New `packs/accounts/app/events/accounts/player_banned.rb` -- like `player_deleted.rb`; published by 7.5's ban action.
- New `packs/game/app/handlers/game/handlers/player_banned.rb`, `config/initializers/event_store.rb` -- pattern `handlers/player_deleted.rb`.
- New `packs/game/app/jobs/game/drop_friends_and_trades_job.rb` and a task in `packs/game/lib/tasks/game.rake` -- pattern `backfill_friend_codes_job.rb` and its task. `self.players_with_ties`: deleted or banned players named by a friendship, an invitation or an open trade.
- `packs/game/app/queries/game/friends_of.rb`, `invitations_of.rb`, `operations/game/accept_invitation.rb` -- also leave out deleted players (the in-flight race window, and players deleted before the sweep).
- `packs/game/app/operations/game/trade_steps.rb` (`friends` comment), `app/controllers/trades_controller.rb` (`edit` and `decline` guards), `app/views/trades/_board.html.erb` (the `!trade.friend.deleted?` guard and its comment) -- remove 5.6's deleted-partner workarounds.
- `app/views/friends/show.html.erb` -- `id="friends-invite"` (+ `tabindex="-1"`) on the invite panel, and the empty line with its link.
- `app/views/trades/_list.html.erb` -- the empty line with its link.
- `app/views/trades/_side.html.erb`, `app/views/trades/_board.html.erb`, `app/views/trades/edit.html.erb`, `app/controllers/trades_controller.rb#edit`, `app/helpers/trades_helper.rb` -- `@own_owned = Game::Quantities`. A helper turns a side's max and owned copies into `nil | :none_owned | :all_reserved`, and the side renders `.trade-side__none` when editing.
- `app/frontend/styles/trades.css`, `friends.css` -- the line's style, if needed.
- `config/locales/{fr,en}.yml` -- `friends.show.empty`/`empty_invite`, `trades.list.empty`/`empty_invite`, `trades.side.none.{title,none_owned,all_reserved,friend_none_owned}`, `accounts.dialog.note`.
- Tests:
  - Rewrite `test/packs/game/deleted_player_partner_test.rb` for the new behaviour; keep its goal-reward case.
  - New `test/packs/game/drop_friends_and_trades_test.rb`: the matrix, the ban handler and the job.
  - Update `test/controllers/trades_controller_test.rb` (the deleted-partner case, the empty line, the counter "nothing to place").
  - Update `test/controllers/friends_controller_test.rb` (the empty line link).
  - Add a deletion-versus-proposal race to `test/packs/game/delete_player_concurrency_test.rb`.
  - Add the rake task to `test/support/rake_tasks.rb`, or wherever its tests live.

## Tasks & Acceptance

**Execution:**
- [ ] `drop_friends_and_trades.rb`, `release_player.rb`, `player_banned.rb` event and handler, `event_store.rb` -- the domain
- [ ] `drop_friends_and_trades_job.rb`, `game.rake` -- the sweep of players already removed
- [ ] `friends_of.rb`, `invitations_of.rb`, `accept_invitation.rb`, `trade_steps.rb` comment -- deleted players left out
- [ ] `trades_controller.rb`, `_board.html.erb` -- 5.6's guards removed; `edit` gives the owned copies
- [ ] `friends/show.html.erb`, `trades/_list.html.erb`, `trades/_side.html.erb`, `trades_helper.rb`, CSS, locales -- the empty states and the dialog note
- [ ] tests listed in the Code Map

**Acceptance Criteria:**
- Given Alice's open trade offering Portal ×2 to Bob, when Bob deletes his account, then Alice's Portal is unreserved, the trade shows "Clos" on her list, and Bob is no longer among her friends nor her invitations.
- Given a player banned with `banned_at` and ties left, when `bin/rails game:drop_friends_and_trades` runs, then their trades are cancelled, their reservations released and their friendships and invitations gone.
- Given a player without friends or trades, when they open Amis or Échanges, then the empty line shows its copy with a link to the invite panel.
- Given a counter form where a side has no copy to place, then that side shows "Aucune carte disponible." and its reason.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- How the operation works, and where it runs:
  - `Game::DropFriendsAndTrades` reads the parties of the player's open trades, takes their bank locks in ascending order and re-reads until no party is missing. It then locks the trade rows, sums the offers per proposer and releases them proposer by proposer (`TradeLocks.holdings`, then `TradeSteps#release`, which skips a holding already gone).
  - The trades are closed as `cancelled`. The invitations are deleted before the friendships.
  - `Game::ReleasePlayer` runs it first (`step`), so a deletion releases the partners' reservations before the deleted player's own rows go.
  - Because it is run from a handler, it publishes no event.
- Bans: `Accounts::PlayerBanned` (new, nobody publishes it yet) is subscribed to `Game::Handlers::PlayerBanned`. Story 7.5's ban action only has to publish it inside its transaction.
  - Until then, the `banned_at` set from the console is covered by `Game::DropFriendsAndTradesJob` and `bin/rails game:drop_friends_and_trades`. The job is one transaction per player, with errors reported. The task aborts with the count still tied.
  - The same task also cuts off accounts deleted before this story. Run it once after the deploy.
- `FriendsOf` and `InvitationsOf` now leave out deleted players too, and `AcceptInvitation` refuses a deleted sender. This covers the short window in which a racing invitation commits around a deletion, and the deletions made before the sweep.
- 5.6's deleted-partner workarounds were removed: the board's no-actions guard, the counter form's redirect and the decline's `:not_friends`. Such a trade is now closed.
  - The 5.6 controller test of that case now checks that the trades show "Clos", read "annulé…" and no longer hold any reserved copy.
  - `test/packs/game/deleted_player_partner_test.rb` (from 7.8) was rewritten for the new behaviour: cancelled, not left open.
- Empty states:
  - Amis: "Aucun ami pour l'instant." with a link to `#friends-invite`. The invite panel gained that id.
  - Échanges: "Aucun échange pour l'instant." with a link to `/friends#friends-invite`.
  - The counter form's sides: "Aucune carte disponible." with its reason, from `TradesHelper#trade_nothing_to_place`. The controller adds `Game::Quantities` for the player's own side (`@own_held`) to tell "none owned" from "all reserved".
- Deletion dialog: the note now names the open trades (fr and en).
- Tests:
  - New `test/packs/game/drop_friends_and_trades_test.rb`: deletion as recipient and as proposer, ban, invitations, idempotence and no event, the race-left rows hidden, the sweep and its failure path through the task.
  - A deletion racing two proposals to the deleted player, in `trade_concurrency_test.rb` (run three times, green). The teardown now also cleans the `Accounts::Player$id` streams.
  - Controller tests for the empty lines and the nothing-to-place line.
- Shared surfaces touched: `config/locales/{fr,en}.yml` (`friends.show.empty*`, `trades.list.empty*`, `trades.side.none.*`, `accounts.dialog.note`), `config/initializers/event_store.rb` and `packs/game/lib/tasks/game.rake`. No migration, no route, no change to the hub menu or the layouts.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0 (quick lens run in-session, subagents unavailable)
- findings:
  - `[medium]` `[defer]` "The picker's states" are not built on the picker itself. The card picker island (5.7) does not exist at this baseline. "Nothing to place" is shown on the counter form's sides; the picker's version is recorded in `deferred` for 5.7.
  - `[low]` `[defer]` The partner gets no live update when a deletion or a ban closes their trade (no event, by AD-10). The private stream and broadcasts belong to 5.9, built in parallel; this is recorded in `deferred` for that merge.
  - `[low]` `[reject]` An open trade already past its expiry, not yet closed by the job (which runs every minute), is closed as `cancelled` rather than `expired`. The partner still sees CLOS with every copy released, the window is at most a minute, and telling the two apart would add a branch for a case not met in everyday use.
  - `[low]` `[patch]` A comment line in `accept_invitation.rb` overflowed the file's wrapping after the edit. It was reflowed.

## Design Notes

Why the lock loop: AD-10 asks for the bank locks in ascending player id, but the partners are known only by reading the open trades before locking. Every trade operation takes both parties' bank locks, so once the player's own lock is held, their set of open trades is frozen. A partner who appeared between the read and the lock (rare) is locked afterwards, out of order. The worst case is a deadlock, which Postgres resolves by aborting one transaction: the deletion rolls back as a whole and can be retried.

## Verification

**Commands:**
- `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane test DB) -- expected: green
- `bin/rails test test/system/friends_test.rb test/system/trades_test.rb test/system/settings_test.rb` (PARALLEL_WORKERS=1) -- expected: green
- `bin/rubocop` on changed Ruby, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused` -- expected: clean

## Auto Run Result

Status: built.

**Summary:** Deleting or banning an account now cuts the player off from the others (R6, AD-14).
- `Game::DropFriendsAndTrades` cancels the player's open trades and releases every copy they reserved, on both sides. It deletes the player's invitations (both directions) and friendships, and publishes nothing.
- A deletion runs it first, inside `Game::ReleasePlayer`.
- A ban runs it through a new `Accounts::PlayerBanned` event and `Game::Handlers::PlayerBanned`; story 7.5's ban action only has to publish the event.
- Accounts already deleted, and bans set from the console, are swept by `Game::DropFriendsAndTradesJob` / `bin/rails game:drop_friends_and_trades`. Run it once after the deploy.
- The empty states are complete:
  - Amis: "Aucun ami pour l'instant." with a link to the invite panel.
  - Échanges: "Aucun échange pour l'instant." with a link to the same panel.
  - The counter form: "Aucune carte disponible." and its reason on a side with no copy left to place.
- The deletion dialog's note now names the open trades.
- Story 5.6's workarounds for a deleted partner's open trade are removed.

**Files:**
- `packs/game/app/operations/game/drop_friends_and_trades.rb` (new) -- the operation.
- `packs/game/app/operations/game/release_player.rb` -- runs it first on a deletion.
- `packs/accounts/app/events/accounts/player_banned.rb`, `packs/game/app/handlers/game/handlers/player_banned.rb` (new), `config/initializers/event_store.rb` -- the ban's event and handler.
- `packs/game/app/jobs/game/drop_friends_and_trades_job.rb` (new), `packs/game/lib/tasks/game.rake` -- the sweep and its task.
- `packs/game/app/queries/game/friends_of.rb`, `invitations_of.rb`, `packs/game/app/operations/game/accept_invitation.rb`, `trade_steps.rb` -- deleted players left out; comments.
- `app/controllers/trades_controller.rb`, `app/views/trades/_board.html.erb` -- 5.6's guards removed; `@own_held` for the nothing-to-place reason.
- `app/helpers/trades_helper.rb`, `app/views/trades/{_side,_screen,edit,_list}.html.erb`, `app/frontend/styles/trades.css` -- the nothing-to-place line and the trades empty line.
- `app/views/friends/show.html.erb` -- `#friends-invite` and the friends empty line.
- `config/locales/{fr,en}.yml` -- empty-state copy, `trades.side.none.*`, the dialog note.
- Tests:
  - New: `test/packs/game/drop_friends_and_trades_test.rb`.
  - Rewritten: `test/packs/game/deleted_player_partner_test.rb`.
  - Added to: `test/packs/game/trade_concurrency_test.rb` (deletion racing proposals), `test/controllers/{trades,friends}_controller_test.rb`.

**Review:** quick lens, run in-session.
- Patched: 1 (low; a comment reflowed).
- Deferred: 2. The picker's states wait for the 5.7 island (medium). The partner's live update waits for the 5.9 merge (low).
- Rejected: 1 (low). An open trade already past its expiry closes as cancelled, not expired: the window is at most a minute, the trade still shows CLOS with its copies released, and telling the two apart would add a branch.
- Patched counts: high 0, medium 0, low 1. Follow-up review recommended: false.

**Verification:**
- `bin/rails test` (non-system, PARALLEL_WORKERS=2, lane DB `gameble_test_5_11`): 1627 runs, 0 failures, 0 errors. Run again after the patch: green.
- The trade and deletion concurrency files and the new test file, run three times: green.
- `bin/rails test test/system/friends_test.rb test/system/trades_test.rb test/system/settings_test.rb` (PARALLEL_WORKERS=1): 14 runs, 0 failures.
- `bin/rubocop` on the changed Ruby files, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` and `unused`, `npm run typecheck`, `npx vitest run` (138 tests): clean.

**Residual risks:**
- A partner whose trade appears between the first read and the player's bank lock is locked out of order. This is rare; a deadlock aborts one transaction, and a deletion then rolls back whole and can be retried.
- Story 5.9's broadcasts must tolerate rows deleted after commit.
- The shared surfaces `config/locales/*.yml` and `trades/_board.html.erb` are likely to conflict with the 5.7 lane, which edits the board and the trades locale block.
- The English copy and the reason lines are autonomous wording, for the author to confirm.
