---
title: 'A counter-proposal from a stale tab is refused'
type: 'bugfix'
ticket: '29'
created: '2026-10-13'
status: done
baseline_revision: '500c21f9089bc31ce468985f32be2e131d99a4f4'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A counter-proposal carries no version of the terms the player saw, so a counter sent from a stale tab (or from a board whose live refresh was held while editing) replaces the friend's newer terms without the player ever seeing them.

**Approach:** The counter form sends the version of the terms it was rendered with (`trade.revision`, as the accept and decline buttons already do), and `Game::CounterTrade` takes a required `revision:` and refuses with `:trade_changed` when it is not the trade's current one, checked inside the lock after the turn and open checks, as `Game::AcceptTrade` does; a missing or unreadable version is refused the same way. The controller sends a `:trade_changed` refusal back to the trade's board (not the counter form), so the player reads the new terms with the trade-changed message. Verify: with one trade open in two tabs, the friend changes the terms and the stale tab's counter is refused with the trade-changed message and the board showing the new terms; a counter from a fresh board goes through.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/app/operations/game/counter_trade.rb` -- take `revision:` and run `current_terms(trade, revision)` after `still_open` in the transaction -- the bug.
- [x] `app/views/trades/_board.html.erb` -- the counter form (`COUNTER_FORM_ID`) carries a hidden `revision` field with `trade.revision` -- the version seen, on the board and on the counter page alike.
- [x] `app/controllers/trades_controller.rb` -- pass `params[:revision]` to `Game::CounterTrade`; on `:trade_changed` redirect to the trade's board, other refusals keep the counter form -- the board shows the new terms.
- [x] `test/packs/game/trade_accept_counter_expire_test.rb` -- the `counter` helper sends the current revision by default; a counter with the version from before the friend's counter is refused with `:trade_changed` and nothing moves; a missing or unreadable version is refused.
- [x] `test/controllers/trades_controller_test.rb` -- the counter form carries the revision (board and counter page); the two-tab scenario: a counter posted with the stale revision redirects to the board, which shows the trade-changed error and the friend's new terms, with nothing changed; a counter with the fresh revision goes through; existing counter posts send the revision.
- [x] `test/packs/game/deleted_player_partner_test.rb`, `test/packs/game/player_activity_test.rb`, `test/packs/game/trade_concurrency_test.rb`, `test/system/live_updates_test.rb`, `test/system/trades_test.rb` -- pass the revision to `Game::CounterTrade` (system tests edited only for the call signature, not run).

**Acceptance Criteria:**
- Given a trade waiting for Hugo whose terms Lea changed after Hugo's counter form was shown, when Hugo sends that form, then the counter is refused, Hugo lands on the trade's board with the trade-changed message and Lea's new terms, and the trade, items and reservations are unchanged.
- Given the same trade reloaded, when Hugo sends a counter from the fresh board, then it goes through.

## Implementation Notes

Oneshot: about 20 lines of code plus tests. `Trade#revision` (the `proposed_at` instant to the microsecond) changes on every counter, and `TradesOf::Row` already exposes it, so the board and the counter page both render it. The counter draft's storage key holds `expires_at`, which a counter also changes, so a stale tab's draft is not restored onto the new terms. A stale tab whose trade is now the friend's turn is still refused by the turn check (`:not_allowed`), as for accept and decline.

Built as planned. The sides are still validated before the version (a stale tab sending an empty side gets `:invalid_offer` on the counter form); the version check sits after `still_open`, as in `Game::AcceptTrade`. The controller picks the redirect with a private `counter_refused_path`. Existing counter posts in the controller test now send the revision; the two-tab test reads the version from the rendered counter form, so it proves the field end to end. Without the operation's check, 4 of the new or extended tests fail. System tests calling `Game::CounterTrade` were updated for the new keyword only and were not run.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` The posted sides are validated against current holdings (`with_sides`, `normalise`, `known_cards`) before the version, so a stale form naming a card a holder no longer holds is refused as `:invalid_request` on the counter form rather than as `:trade_changed` on the board — verified real (`quantities` returns nil on an unknown key), but the counter is still refused and the counter form shows the friend's new terms; it needs the friend to change the terms and a named card to change hands in the same window, and the fix adds a pre-check branch in the controller, so it is not worth it.

## Verification

**Commands:**
- `bin/rails test test/packs/game/trade_accept_counter_expire_test.rb test/controllers/trades_controller_test.rb` -- expected: all pass
- `bin/rails test`, `npm run test:js`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: all pass

## Auto Run Result

- **Summary:** the counter form now sends the version of the terms it was rendered with, and `Game::CounterTrade` refuses with `:trade_changed` when that version is not the trade's current one (or is missing or unreadable), as accept and decline do; the controller sends that refusal to the trade's board, which shows the trade-changed message and the friend's new terms. A counter from a fresh board goes through.
- **Files changed:**
  - `packs/game/app/operations/game/counter_trade.rb` -- required `revision:`, `current_terms` checked in the lock after `still_open`.
  - `app/views/trades/_board.html.erb` -- hidden `revision` field in the counter form.
  - `app/controllers/trades_controller.rb` -- passes `params[:revision]`; `:trade_changed` redirects to the board (`counter_refused_path`).
  - `test/packs/game/trade_accept_counter_expire_test.rb` -- stale-version counter refused with nothing moved, then a current one goes through; no or unreadable version refused.
  - `test/controllers/trades_controller_test.rb` -- the two-tab scenario end to end (version read from the rendered form), the counter page carries the version, a counter without one is refused; existing counter posts send it.
  - `test/packs/game/deleted_player_partner_test.rb`, `player_activity_test.rb`, `trade_concurrency_test.rb`, `test/system/live_updates_test.rb`, `test/system/trades_test.rb` -- pass the revision to `Game::CounterTrade`.
- **Review:** quick lens, 1 finding; 0 patches, 0 deferred, 1 rejected (low: a stale form naming a card no longer held is refused as an invalid request on the counter form; rare, still refused, fix adds a branch). Patched by verdict: high 0, medium 0, low 0.
- **Follow-up review recommended:** false (nothing patched).
- **Verification:** `bin/rails test` 2363 runs, 0 failures; `npm run test:js` 225 tests in 24 files pass; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 695 files, no offenses. Without the operation's check, 4 tests fail.
- **Residual risk:** a stale form whose named cards changed hands is refused with the invalid-request message on the counter form instead of the trade-changed message on the board (see the rejected finding). Pages open before the deploy send no version and get the trade-changed refusal once.
