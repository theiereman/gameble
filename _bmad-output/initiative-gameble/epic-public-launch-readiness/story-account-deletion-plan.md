---
title: 'Account deletion'
type: 'feature'
ticket: '8'
created: '2026-10-07'
status: 'built'
baseline_revision: 'e419296bcc721682f3ba0eafef14b228311cacf9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A deleted player still shows in their friends' lists (presence offline) and a pending invitation from them can still be accepted, until story 5.11 extends the deletion handler; their open trades stay open until declined, cancelled or expired.
    evidence: |-
      Game::FriendsOf and Game::AcceptInvitation filter banned players only; friendships, trades and invitations of a deleted player are left by Game::ReleasePlayer, as the ticket assigns them to epic 5's last story (5.11). Trade operations refuse a deleted partner (:not_friends) and release nothing of theirs since the merge with 5.5.
    location: >-
      packs/game/app/operations/game/release_player.rb
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A player cannot delete their account (R3, CAP-14); their Steam id, name and collection stay forever.

**Approach:** A danger row in the settings opens a dialog where the player types SUPPRIMER (DELETE in English); `Accounts::DeletePlayer` anonymises the record (Steam id and name cleared, token rotated, `deleted_at` set) and publishes `Accounts::PlayerDeleted`; a `Game` handler, under the bank lock, deletes what the player holds (packs, holdings, feed entries, daily bonus claims, friend code); the player is signed out to the hub with a toast.

## Boundaries & Constraints

**Always:** the record stays (foreign keys) but holds no Steam id, no name and a new token; the Steam id signs up again as a new player; a deleted player is never visible (`Game::Visibility`), never signed in (a session holding their id is dropped), refused by every `Game` operation, and skipped by jobs walking players; every bank-writing operation re-checks deletion after taking the bank lock, so an opening, bonus, fill or heal that waited on a deletion writes nothing; the typed word is checked on the server too (case-insensitive, surrounding spaces ignored, paste allowed); strong_migrations rules (expand, then validate).

**Never:** trades, friendships, invitations (story 5.11 extends the handler); export (7.7); a second visibility check; deleting weekly contributions or the player state row (anonymous counts, no personal data); touching the feed's query (Visibility already filters).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|----------|--------------|----------|----------------|
| Delete | signed in, word "supprimer " (fr) | record anonymised, Game rows gone, signed out, hub with toast | none |
| Wrong word | "SUPPRIME", "", "DELETE" in fr | nothing changes, back to settings with alert | flash alert |
| Visitor | signed out | refused, sign_in_required | none |
| Twice | second request of a deleted player | refused (signed out, sign_in_required) | none |
| Sign up again | same Steam id after deletion | a new player with a new bank | none |
| Race | opening concurrent with deletion | no pack, holding or feed row left for the deleted player | opening fails `:player_required` or `:no_pack_available` |
| Old session | another browser with the deleted id | treated as a visitor, session key dropped | none |

</intent-contract>

## Code Map

- `db/migrate/20261007170800_add_deleted_at_to_accounts_players.rb` -- add `deleted_at` datetime, `change_column_null :steam_id, true`, check `(steam_id IS NULL) = (deleted_at IS NOT NULL)` `validate: false`; `..170810_validate_...` validates it (pattern: `20261007110000/110100` visibility migrations). Regenerate `db/schema.rb`.
- `packs/accounts/app/models/accounts/player.rb` -- `deleted?`; steam_id validations `unless: :deleted?`.
- `packs/accounts/app/operations/accounts/delete_player.rb` -- new; model on `set_visibility.rb`/`report_player.rb`: require live player, `transaction { player.lock!; refuse deleted; update!(steam_id: nil, persona_name: nil, token: Player.generate_unique_secure_token, deleted_at:); publish PlayerDeleted (stream "Accounts::Player$id") }` → `Success(player) | Failure(:player_required)`.
- `packs/accounts/app/events/accounts/player_deleted.rb` -- new, like `player_registered.rb`.
- `packs/accounts/app/queries/accounts/players_in_batches.rb` -- always exclude deleted.
- `packs/game/app/operations/game/release_player.rb` -- new `Game::Operation`; accepts only a deleted player; `BankLock.acquire`, then delete_all FeedEntry, DailyBonusClaim, Pack, Holding, FriendCode of the player (FK order); publishes nothing (it runs from a handler, AD-10).
- `packs/game/app/handlers/game/handlers/player_deleted.rb` + `config/initializers/event_store.rb` -- subscribe; `Accounts::PlayerById` then `ReleasePlayer...value!`.
- `packs/game/app/operations/game/operation.rb` -- `require_player` refuses deleted; new private `lock_bank(player)`: `BankLock.acquire` then `Failure(:player_required)` if the row is now deleted (fresh read).
- `open_pack.rb`, `collect_daily_bonus.rb`, `fill_bank.rb`, `heal_bank.rb` -- `BankLock.acquire(player.id)` → `step lock_bank(player)`.
- `packs/game/app/models/game/visibility.rb` -- deleted owner never visible.
- `packs/game/app/jobs/game/backfill_{player_states,friend_codes}_job.rb` -- counts skip deleted players.
- `app/controllers/application_controller.rb` (`current_player`) -- drop a deleted player like a banned one.
- `app/controllers/accounts_controller.rb`, `app/policies/account_policy.rb`, `config/routes.rb` (`resource :account, only: :destroy`) -- check the word against `t("accounts.dialog.word")`, call the operation, `reset_session` (keep motion cookie like sign-out), redirect home with notice; rate limited.
- `app/views/accounts/_dialog.html.erb` -- modal like `reports/_dialog.html.erb`: note, label "Tapez SUPPRIMER pour confirmer", text field, danger submit "SUPPRIMER DÉFINITIVEMENT", ANNULER.
- `app/frontend/lib/confirm_word.ts` (+ `.test.ts`) and `app/frontend/controllers/confirm_word_controller.ts` -- enable the submit when the field matches.
- `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css` -- the COMPTE row (danger, opens the dialog) and dialog styles.
- `config/locales/{fr,en}.yml` -- copy, `errors.accounts.wrong_word`.

## Tasks & Acceptance

**Execution:**
- [ ] migrations, schema, Player, event, `Accounts::DeletePlayer`, PlayersInBatches -- the Accounts side
- [ ] `Game::ReleasePlayer`, handler, subscription, `require_player`/`lock_bank`, the four bank operations, Visibility, backfill counts -- the Game side
- [ ] controller, policy, route, current_player, dialog, settings row, Stimulus controller, CSS, locales -- the surface
- [ ] tests: DeletePlayer, ReleasePlayer/handler (rows gone, other players untouched), sign up again, Visibility, Game operations refuse deleted, concurrency (opening vs deletion, no orphan), accounts controller (word, visitor, sign-out, old session), policy, vitest for the word, system test of the dialog

**Acceptance Criteria:**
- Given a signed-in player, when they type the word and confirm, then they land signed out on the hub with the deletion toast and their profile URL shows the unavailable page.
- Given the dialog, while the field does not hold the word, then "SUPPRIMER DÉFINITIVEMENT" is disabled; typed or pasted in any case it enables.
- Given a deleted player's Steam id, when it signs in, then a new player is created with a fresh bank.
- Given an opening and a deletion racing, then no game row of the deleted player remains.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- Lock order (AD-10) decided the operation's shape: `Accounts::DeletePlayer` locks the player row `FOR NO KEY UPDATE` (serialises two deletions, compatible with the `FOR KEY SHARE` an opening's inserts take), publishes `Accounts::PlayerDeleted` (the handler takes the bank lock and deletes the rows), and only then anonymises: that UPDATE changes unique columns, so it takes `FOR UPDATE`, which deadlocked against an opening holding the bank lock when done first (seen in the concurrency test). `Game::ReleasePlayer` therefore accepts any saved player, not only a deleted one; it is run only by the handler.
- `Game::Operation#lock_bank` replaces `BankLock.acquire` in OpenPack, CollectDailyBonus, FillBank and HealBank: after the lock it reads `deleted_at` afresh; a mutation check (re-check removed) makes the concurrency tests fail (a bonus refills a deleted bank).
- Kept on purpose: weekly contributions (anonymous counts in the community goal), the game state row (a watermark only), reports by or about the player (the record is anonymised). Deleted: feed entries, daily bonus claims, packs, holdings, friend code.
- The shared card page names no owner (story 7.2), so "shared cards show as unavailable" is the profile and its set pages: the token is rotated (old links 404 with the unavailable page) and `Game::Visibility` refuses a deleted owner.
- The wrong-word message lives at `accounts.destroy.wrong_word` (not `errors.accounts.*`: it is the web layer's check, not an operation failure); the dialog's system test went into `test/system/settings_test.rb` beside the other settings rows rather than a new file.
- Copy: the mock's note mentions trades and card backs, which this story does not erase yet; the note says collection, boosters and profile.
- Migrations 20261007170800/170810 touch `accounts_players` (steam_id nullable, `deleted_at`, check constraint); `db/schema.rb`, `config/routes.rb` and both locales changed.
- Merge of develop at 3fc4caa (7.6, 5.5, 6.5, 5.3), reconciled so the deletion's guarantees hold across them:
  - 7.6: `HealBank` and `FillBank` keep 7.6's rules (TopUpBank `heal` at publication) and take the bank lock through `lock_bank`; `bank_races_test.rb` passes unchanged.
  - 6.5: `Game::GrantGoalReward` takes the bank lock through `lock_bank` (a grant that waited on a deletion writes nothing), `GrantGoalRewardsJob` skips deleted players, and `Game::ReleasePlayer` deletes the player's `game_goal_rewards` rows (they reference the reward packs it deletes; the weekly contributions still stay for the goal's total).
  - 5.5: trades stay 5.11's, but `TradeSteps#friends` now treats a deleted partner as no friend, so accepting, countering or proposing to a deleted player fails `:not_friends` and the card moves never create a holding for them; `TradeSteps#release` skips cards without a holding, so declining, cancelling or the expiry job closes a deleted proposer's trade without raising.
  - 5.3: `current_player` is nil for a deleted player, so `note_presence` queues nothing for their sessions; `Accounts::NoteLastSeen` also skips a deleted row (a job queued before the deletion writes nothing), and the deletion clears `last_seen_at`. `game_player_states` now holds the latest activity, so `Game::ReleasePlayer` deletes the state row too (last, per AD-10); `Game::FriendsPresence` already tolerates a missing row.
  - `db/schema.rb` regenerated by running every migration on a fresh database.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` A deleted player stays in friends' lists and can be proposed a trade or have a pending invitation accepted — the ticket assigns trades and friendships (and with them invitations) to story 5.11; recorded in `deferred`.
  - `[low]` `[patch]` `first_holding_the_lock` in the concurrency test would hang if the first operation raised before signalling — the signal and the wait moved into an `ensure`; test run three times, green.
  - `[low]` `[reject]` Reports filed by or about a deleted player stay, naming the anonymised record — no identifying data remains on the record and the moderation queue (7.5) is not built; filtering them adds branches for a case not met in everyday use.
  - `[low]` `[reject]` The Code Map named `errors.accounts.wrong_word` and a new system test file; the code uses `accounts.destroy.wrong_word` and `settings_test.rb` — the fix would edit this build's plan; recorded in Implementation Notes.

## Verification

**Commands:**
- `bin/rails test` (PARALLEL_WORKERS=2, own test DB) -- green
- `bin/rails test test/system/settings_test.rb` (PARALLEL_WORKERS=1) -- green
- `bin/rubocop` on changed files, `bin/packwerk check`, `bundle exec i18n-tasks health`, `npm run typecheck`, `npx vitest run` -- green

## Auto Run Result

Status: built.

**Summary:** a player deletes their account from the settings' COMPTE row: a dialog asks for SUPPRIMER (DELETE in English; any case, spaces ignored, paste allowed), enabled by a Stimulus controller and checked again on the server. `Accounts::DeletePlayer` anonymises the record (Steam id and name cleared, token rotated, `deleted_at`) and publishes `Accounts::PlayerDeleted`; `Game::Handlers::PlayerDeleted` runs `Game::ReleasePlayer` under the bank lock (feed entries, bonus claims, packs, holdings, friend code deleted). The player is signed out to the hub with a toast; other sessions of the player become visitors; the Steam id signs up again as a new player; every Game operation and job skips a deleted player, and bank operations re-check deletion under the bank lock.

**Files:**
- `db/migrate/20261007170800_*`, `20261007170810_*`, `db/schema.rb` -- `deleted_at`, nullable `steam_id`, check constraint (expand, validate).
- `packs/accounts/app/models/accounts/player.rb` -- `deleted?`, Steam id validation skipped when deleted.
- `packs/accounts/app/operations/accounts/delete_player.rb`, `packs/accounts/app/events/accounts/player_deleted.rb` -- the operation and its event.
- `packs/accounts/app/queries/accounts/players_in_batches.rb` -- never yields a deleted player.
- `packs/game/app/operations/game/release_player.rb`, `packs/game/app/handlers/game/handlers/player_deleted.rb`, `config/initializers/event_store.rb` -- the Game side.
- `packs/game/app/operations/game/operation.rb` and `open_pack.rb`, `collect_daily_bonus.rb`, `fill_bank.rb`, `heal_bank.rb` -- `require_player` refuses deleted; `lock_bank` re-checks under the lock.
- `packs/game/app/models/game/visibility.rb` -- a deleted owner is never visible.
- `packs/game/app/jobs/game/backfill_{player_states,friend_codes}_job.rb` -- counts leave deleted players out.
- `app/controllers/accounts_controller.rb`, `app/policies/account_policy.rb`, `config/routes.rb` -- `DELETE /:locale/account`.
- `app/controllers/application_controller.rb` -- a deleted player's session is dropped.
- `app/views/accounts/_dialog.html.erb`, `app/views/settings/show.html.erb`, `app/frontend/styles/settings.css`, `app/frontend/lib/confirm_word.ts`, `app/frontend/controllers/confirm_word_controller.ts` -- the row and the dialog.
- `config/locales/{fr,en}.yml` -- copy.
- Tests: `test/packs/accounts/delete_player_test.rb`, `test/packs/game/delete_player_concurrency_test.rb`, `test/controllers/accounts_controller_test.rb`, `test/policies/account_policy_test.rb`, `app/frontend/lib/confirm_word.test.ts`, additions to `visibility_test.rb`, `settings_controller_test.rb`, `test/system/settings_test.rb`.

**Review:** quick lens, in-session. 1 patch (low: test helper hang), 1 deferred (medium: friends, trades and invitations of a deleted player, story 5.11), 2 rejected (reports kept: no identifying data left, adds branches; plan naming drift: fix would edit the plan). Patched counts: high 0, medium 0, low 1. Follow-up review recommended: false.

**Verification:** `bin/rails test` (PARALLEL_WORKERS=2): 1463 runs, 0 failures; `bin/rails test test/system/settings_test.rb test/controllers/settings_controller_test.rb` (PARALLEL_WORKERS=1): 48 runs, 0 failures; concurrency test run three times after the patch, green; `bin/rubocop` on changed Ruby files, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `npm run typecheck`, `npx vitest run` (135 tests): clean; `bundle exec i18n-tasks health`: no missing or unused key (its normalization and one interpolation notice predate this change).

**Merge with develop (3fc4caa):** see Implementation Notes. After the merge: `bin/rails test` (PARALLEL_WORKERS=2), the concurrency test three times, `bank_races_test.rb`, the settings and hub system tests (PARALLEL_WORKERS=1), rubocop, packwerk and `i18n-tasks missing` were run again: 1552 runs, 0 failures; concurrency test 3/3 green; `bank_races_test.rb` green; settings and hub system tests 20 runs, 0 failures; rubocop, packwerk and i18n-tasks missing clean.

**Residual risks:** until 5.11, a deleted player's friendships, open trades and pending invitations remain (deferred). Story 7.9 adds the wider race tests across bank operations.
