---
title: 'Fixes from the epic retrospective'
type: 'bugfix'
ticket: '13'
created: '2026-10-09'
status: 'built'
baseline_revision: '746f3ce0d9443c2f7351cecb2df0bc877c82751f'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The epic 5 retrospective found six defects at the seams between stories:
- An accept or a decline can act on terms the player never saw, because a counter keeps the trade's token.
- A trade past its expiry but not yet swept blocks a new proposal while the board shows it closed, and the expiry job drops its failures silently.
- Crossing invitations leave a stale pending invitation and announce the friendship twice.
- An ignored invitation vanishes from the sender's view, which tells them they were ignored, and can be re-sent at once.
- An empty trade side reads "0 cartes" in French.
- Planning ids remain in the epic's code and tests.

**Approach:** Fix each in the operation that owns it, with a test for the condition found:
- Accept and decline carry the trade's `proposed_at` as the version the player saw.
- Proposing first expires the pair's due trade in its own operation.
- Invitation writes take the pair's bank locks.
- The sender's view keeps ignored invitations as pending.
- The French locale gets the `zero` form.
- The planning ids are stripped.

## Boundaries & Constraints

**Always:**
- Every write goes through an operation, and each operation publishes at most its one event inside its own transaction.
- Locks are taken in the existing order: bank locks in ascending player id, then holdings, then player state.
- Every new failure code has `errors.game.<code>` in both `en.yml` and `fr.yml`.
- Database ids never reach the HTML.
- Code and tests carry no planning ids.

**Never:**
- No migration and no `db/schema.rb` change.
- No change to `TradesOf.state_of` semantics, to cancel or expire call sites, or to `TradeBoard.tsx`.
- None of the following, which are out of scope:
  - the ban action (epic 7);
  - the profile privacy rule;
  - the friend row's trade button;
  - the structure findings deferred to epic 12.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Stale accept | B's tab shows terms at `proposed_at` T1; A countered since (T2) and it is B's turn again | Nothing moves; B sees the "trade changed" message on the current board | `Failure(:trade_changed)` |
| Stale decline | Same as stale accept, with decline | Trade stays open | `Failure(:trade_changed)` |
| Accept and decline without `seen` | A POST with no version | Refused | `Failure(:trade_changed)` |
| Fresh accept | `seen` equals `proposed_at` (microseconds) | Swap as today; the toast names the swapped cards | No error expected |
| Proposal after expiry | The pair's open trade has `expires_at` in the past and the job has not run | That trade expires (`TradeExpired`, offer released), then the new proposal is created (`TradeProposed`) | A pair trade still in its 7 days gives `:trade_already_open` |
| Expiry job failure | `ExpireTrade` returns a failure other than `:trade_not_open` | Reported through `Rails.error.report`; the batch continues | `:trade_not_open` from a race is skipped silently |
| Crossing invitations | A→B and B→A pending; B accepts A's | One friendship, no pending or ignored row left between them, one `InvitationAccepted` | Accepting the other one gives `:not_found` |
| Accept when already friends | Friendship exists, invitation still pending | The invitation is closed; nothing published | `Failure(:already_friends)` |
| Ignored, seen by the sender | B ignored A's invitation | A's sent list still shows it pending; A re-sending gives `:already_sent` | — |
| Ignorer invites later | B ignored A's; B now invites A | A new B→A invitation, pending, which A can accept | — |
| Banned sender | The sender's `banned_at` is set, the invitation still pending | Accept refused; no friendship | `Failure(:not_found)` |

</frozen-after-approval>

## Code Map

**Trades**

- `packs/game/app/operations/game/trade_steps.rb`: `find_trade`, `lock_trade` (`TradeLocks.players`, then `Trade.lock.find`), `turn`, `still_open`, `not_expired`. Add a step `same_terms(trade, seen)` here.
- `packs/game/app/operations/game/accept_trade.rb`: takes `seen:`; check `same_terms` after `still_open`, inside the lock.
- `packs/game/app/operations/game/close_trade.rb`: base class of `DeclineTrade`, `CancelTrade` and `ExpireTrade`, which only set `STATUS`, `EVENT` and `PARTY`. Take an optional `seen:` here, checked only when the subclass requires it (decline), so cancel and expire keep their call sites.
- `packs/game/app/operations/game/counter_trade.rb:28`: writes `proposed_at: now`. Only this file and `propose_trade.rb:46` write it, so it serves as the revision. `updated_at` is unusable because closing bumps it.
- `packs/game/app/operations/game/propose_trade.rb`: the transaction takes `TradeLocks.players`, then `friends`, then `no_open_trade` (`Trade.in_progress`). Before the transaction, expire the pair's due trade: `Trade.due(now)` for the pair's low and high ids → `ExpireTrade.new.call(player: <proposer>, trade_id:)`, ignoring `:trade_not_open`.
- `packs/game/app/jobs/game/expire_trades_job.rb:12`: discards the result. Copy `drop_friends_and_trades_job.rb:16-18` (`value!` plus `Rails.error.report`), skipping `:trade_not_open`.
- `packs/game/app/queries/game/trades_of.rb`: add `proposed_at` to `Row` (`Data.define` at line 8 and `Row.new` around lines 59-61).
- `app/controllers/trades_controller.rb`: `accept` (86-96), `decline` (98-105), `answer` (179-186), `refused` (193-195, through `Game::Operation.failure_message`). Pass `seen: params[:seen]`.
- `app/views/trades/_board.html.erb:44,48`: `ButtonComponent.new(href:, method: :post)` already accepts `params:` as hidden fields. Add `params: { seen: trade.proposed_at.iso8601(6) }`.
- `config/locales/{en,fr}.yml`: `errors.game` block (en around line 988, fr around 1010). Add `trade_changed`.

**Invitations**

- `packs/game/app/operations/game/send_invitation.rb`:
  - take `TradeLocks.players(player.id, recipient.id)` first in the transaction;
  - `reverse` already uses `.pending`, so an ignored row is never accepted;
  - in `create_pending`, count an `ignored` row from the same sender as `:already_sent`.
- `packs/game/app/operations/game/accept_invitation.rb`:
  - find the invitation by token, take the pair lock, then re-read it with `.lock`;
  - if a friendship already exists, close the invitation and return `Failure(:already_friends)`, which both locales already have;
  - on success, close every other pending or ignored row between the pair, in both directions, as `accepted`.
- `packs/game/app/models/game/trade_locks.rb` and `bank_lock.rb`: re-entrant advisory locks. Do not lock `PlayerState`.
- `packs/game/app/queries/game/invitations_of.rb:9,18-21`: `sent` also includes the player's `ignored` rows; `received` stays pending only.
- Unique index `index_game_invitations_one_pending_per_pair` is partial on `status = 'pending'`, so an ignored row never conflicts with a new invitation.

**Locale and ids**

- `config/locales/fr.yml:693-695` `trades.side.cards`: add `zero: "0 carte"`, the same shape as lines 748-751.
- Planning ids: in the files of this epic's surfaces, strip every `AD-n`, `CAP-n`, `R-n`/`Rn`, "story/stories n.n", `EXPERIENCE.md` and `DESIGN.md`. Carry the intent in names, keeping only one-line external constraints.
  - `app/controllers/sessions_controller.rb` and `accounts_controller.rb`;
  - `packs/game/app/handlers/game/handlers/player_registered.rb`;
  - `packs/game/app/jobs/game/backfill_player_states_job.rb`;
  - `packs/game/app/models/game/{player_state,visibility}.rb`, plus `operation.rb` and `bank_lock.rb` when touched;
  - `packs/game/app/operations/game/{create_player_state,release_player}.rb`;
  - `test/controllers/{accounts,public_profiles,reports,sessions}_controller_test.rb`;
  - `test/fixtures/game/player_states.yml`;
  - `test/packs/game/{feed,player_state,visibility}_test.rb`.

**Tests to extend**

- `test/packs/game/trade_accept_counter_expire_test.rb`: helpers `accept` and `counter`; job tests around lines 221-290.
- `test/packs/game/trade_concurrency_test.rb` and `test/packs/game/invitation_test.rb`: helpers `send_by_code` and `friends?`; to ban a sender, `update_columns(banned_at:)`.
- `test/controllers/trades_controller_test.rb`: accept at line 138, refused at 174, decline at 189.
- `test/system/trades_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `trade_steps.rb`, `accept_trade.rb`, `close_trade.rb`, `decline_trade.rb` -- `same_terms` step on accept and decline -- refuse terms the player did not see
- [x] `trades_of.rb`, `_board.html.erb`, `trades_controller.rb`, `en.yml`, `fr.yml` -- carry `seen`; add `errors.game.trade_changed` in both locales -- the board posts the version it showed
- [x] `propose_trade.rb` -- expire the pair's due trade in its own operation before proposing -- one event per transaction
- [x] `expire_trades_job.rb` -- report failures except `:trade_not_open` -- failures stop vanishing
- [x] `send_invitation.rb`, `accept_invitation.rb` -- pair locks, already-friends path, close the pair's other rows, ignored counts as already sent -- crossing and ignore cases
- [x] `invitations_of.rb` -- ignored rows stay in the sender's `sent` -- the sender cannot tell
- [x] `fr.yml` -- `zero` for `trades.side.cards` -- French empty side
- [x] Files listed under ids -- strip planning ids -- AGENTS.md policy
- [x] Tests -- one per matrix row, in `trade_accept_counter_expire_test.rb`, `trade_concurrency_test.rb`, `invitation_test.rb`, `trades_controller_test.rb`, plus a system test of a stale accept in `trades_test.rb` -- protect each fix

**Acceptance Criteria:**
- Given an empty side on the draft board in French, when it renders, then it reads with the `zero` form, not "0 cartes".
- Given the epic's code and tests, when searched with `rg -n '\b(AD|CAP)-[0-9]+|\bR-?[0-9]+\b|stor(y|ies) [0-9]+\.[0-9]+|EXPERIENCE\.md|DESIGN\.md'` over the listed files, then nothing matches.

## Implementation Notes

- `AcceptTrade#call` takes a required `seen:`; `CloseTrade#call` takes `seen: nil` and checks it through a `current_terms_seen` hook that only `DeclineTrade` overrides, so cancel and expire keep their call sites. `seen` accepts a `Time` or an ISO 8601 string; anything else reads as no version.
- `AcceptInvitation` returns `Failure(:already_friends)` after its transaction commits, so the closed invitation is kept (a Failure inside `transaction` would roll the close back).
- `Invitation` gains the scopes `unanswered` (pending or ignored) and `between`. `Counterparts` counts the removed player's ignored received invitations too, so a sender whose sent list still shows one gets the live friends notice when that recipient is banned or deleted.
- The listed files lost their planning ids; header comments that only restated intent went with them, and `bank_lock.rb` keeps the lock order as one line.
- The system test of a stale accept removes the page's `turbo-cable-stream-source` elements first, so a live refresh cannot replace the stale board before the click.

## Plan Change Log

## Review Triage Log

### 2026-10-09: thorough review, pass 1 (blind-hunter, edge-case-hunter, verification-gap, intent-alignment)

Counts: high 0, medium 1, low 6, false 2, maybe-false 0, rejected-low 10. Routes: 6 patch, 2 defer, the rest rejected.

| Lens | Finding | Verdict | Route | Evidence |
|---|---|---|---|---|
| verification-gap | `Counterparts.invited` now counts ignored received invitations; no test would catch a revert | medium | patch | Pre-verified: `player_stream_test.rb:104` builds only a pending invitation. Patch: a deletion variant where the invitation was ignored first |
| verification-gap | `ProposeTrade#expire_due_trade`'s `:trade_not_open` branch has no test | low | patch | Pre-verified: the only `ExpireTrade` stubs are in the job tests. Patch: a stubbed expiry that answers `:trade_not_open` |
| edge-case | A stale answer to an expired trade reports "changed" instead of "expired" | low | patch | `accept_trade.rb` ran `same_terms` before `not_expired`; reordering is a direct correction |
| edge-case, intent-alignment | `IgnoreInvitation` does not take the pair's bank locks the Approach names | low | patch | `ignore_invitation.rb` takes only the row lock. Patch: pair lock, then re-read |
| blind | `CLOSED_MEANWHILE` is defined in both `ProposeTrade` and `ExpireTradesJob` | low | patch | Two definitions of one rule. Patch: one constant on `ExpireTrade` |
| blind, intent-alignment | Planning ids remain in files the diff touches, and in four epic-5 lines | low | patch | `en.yml:1,866`; `fr.yml:1,887,956`; `first_discovery_and_set_completion_test.rb:4`; `lib/application_operation.rb:3,41`; `reports/_dialog.html.erb`; `report_player.rb`; `settings_controller.rb`; `import_runs_controller_test.rb` |
| blind | Planning ids remain repo-wide (about 800 matches outside this story's files) | low | defer | Pre-existing; to epic 12 |
| blind | The counter form carries no version, so a stale tab's counter replaces newer terms | medium | defer | Pre-existing; the Intent names accept and decline only |
| blind | The DB index enforces one *pending* invitation per direction, not one unanswered | low | defer | App code enforces it under the pair lock; an index on `status IN (pending, ignored)` needs a migration, which the story forbids |
| edge-case | A counter between the due pick and `ExpireTrade` makes a proposal fail with `:not_allowed` | false | reject | `CounterTrade` checks `not_expired` (`counter_trade.rb:18`), so a due trade cannot be countered |
| edge-case | The job reports a trade countered between the pluck and the expiry | false | reject | Same refutation: a due trade cannot be countered |
| edge-case, verification-gap, intent-alignment | After B ignores A and then invites A, A sees B in both sent and received | low | reject | Rare (ignore, then re-invite), and accepting closes both rows (`close_pair`); the fix adds a filtering branch |
| edge-case | The already-friends path publishes nothing, so the sender's open page keeps a closed row until reload | low | reject | Reachable only from rows left before this change, since an accept now closes every row of the pair |
| blind | A stale tab after one's own counter gets `:not_allowed` instead of `:trade_changed` | low | reject | Needs two tabs of the same player; the board is shown again either way (`answer`) |
| blind | `AcceptInvitation` returns `Failure(:already_friends)` after committing the close | low | reject | The frozen matrix asks for exactly this. The one nested caller (`SendInvitation`) checks `not_friends` under the same lock first, so it cannot reach this path |
| blind | `TradeLocks` is a misleading name for invitation writes, and they contend with bank operations | low | reject | The plan chose the existing locks; the contention is one short transaction per invitation |
| blind | `close_pair` relabels ignored rows `accepted` with `update_all` | low | reject | Status history only; no reader distinguishes them once the pair is friends |
| blind | A pre-deploy board without `seen` says "changed" on its first answer | low | reject | Happens once per open board after the deploy; the board is shown again |
| blind | Tests pass `seen` inconsistently (in-memory vs reloaded) | low | reject | All pass; ActiveRecord rounds to microseconds on assignment |
| edge-case | Header comments removed from `release_player.rb` and `backfill_player_states_job.rb` | low | reject | Follows AGENTS.md's no-comment rule. The backfill instruction lives in the rake task and `pending-approvals.md` |
| intent-alignment | Other `Trade.in_progress` readers (badge, counterparts) still count a due trade until the sweep | low | reject | Pre-existing, and lasts at most one sweep interval |

## Design Notes

Expiring before proposing runs `ExpireTrade` outside `ProposeTrade`'s transaction, so each transaction keeps its single event and `PlayerStream` notifies the partner of the expiry as usual. A race where another request closes the trade between the two is harmless: `ExpireTrade` returns `:trade_not_open`, and the proposal proceeds or meets the unique index as today.

`seen` is compared as an instant parsed from ISO 8601 with microseconds, because a counter within the same second must still change the version.

## Verification

**Commands:**
- `bin/rails test test/packs/game test/controllers/trades_controller_test.rb test/controllers/invitations_controller_test.rb test/controllers/friends_controller_test.rb` -- expected: 0 failures
- `bin/rails test test/system/trades_test.rb test/system/friends_test.rb test/system/live_updates_test.rb` -- expected: 0 failures
- `bin/rails test` -- expected: 0 failures
- `bin/rails test:system` -- expected: 0 failures (the full suite, which the retrospective found never ran during the epic)
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: green
