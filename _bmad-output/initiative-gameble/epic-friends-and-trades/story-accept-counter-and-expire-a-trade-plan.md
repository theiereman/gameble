---
title: 'Accept, counter and expire a trade'
type: 'feature'
ticket: '5'
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
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      AcceptTrade raises quantities but publishes no Game::SetCompleted (AD-10).
    evidence: |-
      AD-10 asks every operation that raises a player's quantities to publish one Game::SetCompleted per set completed for the first time. No such event, table or handler exists yet (Game::OpenPack does not publish it either); whoever builds set completion must cover AcceptTrade as well as OpenPack.
    location: >-
      packs/game/app/operations/game/accept_trade.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** An open trade (5.4) can only be cancelled or declined: the friend cannot accept or counter it, and nothing closes a trade left 7 days, so its offer stays reserved forever (R2, R3, R4).

**Approach:** In `Game`, three operations on the existing tables, each one transaction with one identifier-only event under AD-10's lock order: `AcceptTrade` (refuses past expiry, checks the requested cards still free, moves both sides, marks gains as NOUVEAU), `CounterTrade` (releases the old offer, replaces both sides, reserves the new offer, swaps proposer and recipient, restarts the 7 days), `ExpireTrade`; and `Game::ExpireTradesJob`, recurring, one `ExpireTrade` per due trade. No screen, no migration.

**Decisions (autonomous run, author away):** only the recipient (the player whose turn it is) accepts or counters; the counter keeps the trade row, its new `proposer_id` is the counterer, `proposed_at` becomes the counter's time and `expires_at` that time + 7 days; accept and counter past `expires_at` fail `:trade_expired` (the job closes it), cancel and decline keep their 5.4 behaviour; accept and counter require the pair still friends and the other party not banned (`:not_friends`), like propose; a requested line with more copies than the recipient's `quantity - reserved` fails `:requested_cards_unavailable`, nothing moves; per player and card the net change is applied (A-for-A allowed), `last_gained_at` is set to the acceptance time only where that player's quantity rises (AD-26), on both players; holdings left at 0 stay as rows (every reader filters `quantity > 0`); events `Game::TradeAccepted`, `TradeCountered`, `TradeExpired`, data `{ trade_id:, proposer_id:, recipient_id: }` on the (new) proposer's stream; `ExpireTrade` acts for the trade's proposer and accepts a banned one (the clock acts, not the player), only for a trade past `expires_at` (`:trade_not_expired` otherwise); the job runs every minute in development and production (config/recurring.yml); `Game::SetCompleted` (AD-10) is not built yet and stays out.

## Boundaries & Constraints

**Always:** writes only through Game operations (AD-3); `quantity >= reserved >= 0`; lock order: both bank locks ascending, then the trade row, then holdings by ascending player then card-season (AD-6, AD-10); one event per state change, none on failure; one trade per job transaction, one failing trade reported and skipped.

**Never:** screens, controllers, broadcasts, migrations, the SetCompleted event, changes to ProposeTrade/CancelTrade/DeclineTrade behaviour.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Accept | open, not expired, request free | `accepted`, both sides moved, offer unreserved, gains `last_gained_at = now`, `TradeAccepted` | n/a |
| Accept, request no longer free | recipient's `quantity - reserved` < asked | nothing moves, trade open | `:requested_cards_unavailable` |
| Accept / counter past expiry | `expires_at <= now` | nothing moves | `:trade_expired` |
| Accept / counter by proposer, stranger, closed trade | any | nothing moves | `:not_allowed`, `:trade_not_found`, `:trade_not_open` |
| Counter | recipient, valid sides, enough free copies | old offer released, new offer reserved, items replaced, roles swapped, expiry restarted, `TradeCountered` | `:invalid_offer`, `:invalid_request`, `:insufficient_copies` (nothing changed) |
| Expire | open trade past `expires_at` | `expired`, offer released, `TradeExpired` | `:trade_not_expired`, `:trade_not_open` |
| Job | due and not-due trades | only due ones expire, one per transaction | an error is reported, the others still expire |

</intent-contract>

## Code Map

- `packs/game/app/operations/game/close_trade.rb` -- base of Cancel/Decline: `find_trade` (party check by `PARTY`), `still_open`, `release`; reuse its pattern, do not change its behaviour. `ExpireTrade` may subclass it with an overridden player check and an expiry step.
- `packs/game/app/operations/game/propose_trade.rb` -- `normalise`, `integer`, `known_cards`, `friends`, `enough_copies`, `create_items`, `reserve`: extract the side checks to a shared module (e.g. `Game::TradeSides` in `models/game/trade_sides.rb`) so CounterTrade reuses them; ProposeTrade's results must not change.
- `packs/game/app/models/game/trade_locks.rb` -- `players` (bank locks ascending), `holdings(player_id, ids)` (one player's rows, `FOR UPDATE`, ascending card-season); call it per player in ascending player id.
- `packs/game/app/models/game/trade.rb`, `trade_item.rb` -- `LIFETIME`, `open?`, sides; add `expired?(now)`/a `due(now)` scope.
- `packs/game/app/operations/game/open_pack.rb#credit` -- how a gain sets `last_gained_at` (AD-26).
- `packs/game/app/operations/game/operation.rb` -- `require_player` refuses banned; `stream_name`.
- New: `packs/game/app/operations/game/{accept,counter,expire}_trade.rb`, `packs/game/app/events/game/trade_{accepted,countered,expired}.rb`, `packs/game/app/jobs/game/expire_trades_job.rb`.
- `config/recurring.yml` -- add `expire_trades` (anchor, development and production), as `sum_weekly_goal`.
- `config/locales/{en,fr}.yml` `errors.game` -- add `trade_expired`, `requested_cards_unavailable`, `trade_not_expired`.
- Tests: `test/packs/game/trade_test.rb` style (fixtures `accounts_players(:player|:moderator|:administrator|:banned)`, `catalog_card_seasons(...)`), `trade_concurrency_test.rb` (`together`, non-transactional, teardown cleans events).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/game/app/models/game/trade_sides.rb`, `propose_trade.rb` -- extract shared side validation, friendship and reservation helpers -- reuse by CounterTrade
- [ ] `packs/game/app/operations/game/accept_trade.rb`, `events/game/trade_accepted.rb` -- AcceptTrade per the matrix
- [ ] `packs/game/app/operations/game/counter_trade.rb`, `events/game/trade_countered.rb` -- CounterTrade per the matrix
- [ ] `packs/game/app/operations/game/expire_trade.rb`, `events/game/trade_expired.rb`, `models/game/trade.rb` -- ExpireTrade and the due scope
- [ ] `packs/game/app/jobs/game/expire_trades_job.rb`, `config/recurring.yml` -- recurring job, one trade per transaction, errors reported and skipped
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- new error codes
- [ ] `test/packs/game/trade_accept_counter_expire_test.rb` -- matrix cases; `test/packs/game/trade_concurrency_test.rb` -- simultaneous acceptances, accept vs counter/cancel; `test/packs/game/expire_trades_job_test.rb` -- job and recurring entry

**Acceptance Criteria:**
- Given an open trade, when the recipient accepts, then both players' quantities change by exactly both sides in one transaction, the proposer's reservation is released, and a gained card shows as new in `Game::CollectionSlots` for its receiver.
- Given an acceptance that fails any check, then no holding, reservation, item or status changed and no event is published.
- Given a countered trade, then the turn is the other player's (only they can accept or counter), its offer is reserved, the previous offer released, and it expires 7 days after the counter.
- Given two acceptances at once of two trades requesting the recipient's last copy, or of the same trade, then exactly one succeeds and `0 <= reserved <= quantity` everywhere; no deadlock.
- Given trades 7 days after their last send or counter, when the job runs, then each is `expired` and its offer released, trades not yet due stay open.

## Implementation Notes

Subagents unavailable, done in-session (implementation and the quick review lens). The shared steps of ProposeTrade moved to `Game::TradeSteps` (`packs/game/app/operations/game/trade_steps.rb`, a mixin of private steps) rather than a model; ProposeTrade's results are unchanged (its 5.4 tests pass as they were). CloseTrade (cancel, decline, and now expire) re-checks the acting party under the trade-row lock, since a counter now swaps the roles; it gained two hooks, `acting_player` and `closable`, that ExpireTrade overrides (a banned proposer allowed; `:trade_not_expired` before the expiry). Gains insert a holding row when the receiver had none; a holding given down to zero stays as a row (every reader filters `quantity > 0`). The `requested_cards_unavailable` copy follows the copy deck's "EXEMPLAIRES INSUFFISANTS ... nothing moves". The job's due query rides on the open-trade partial index; no migration. Tests: `test/packs/game/trade_accept_counter_expire_test.rb` (18), four new races in `test/packs/game/trade_concurrency_test.rb`. Not here, for later stories: feed entry and goal count of a concluded trade (epic 6 handlers on `Game::TradeAccepted`), broadcasts (5.9).

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 1, false 3, maybe-false 0 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[defer]` AcceptTrade raises quantities without Game::SetCompleted (AD-10) — the event and its set-completion rows do not exist anywhere yet (OpenPack lacks it too); recorded in `deferred`.
  - `[false]` `[reject]` the due-trades query of ExpireTradesJob has no index on `expires_at` — `status = 'open'` is the predicate of `index_game_trades_one_open_per_pair`, so the scan is bounded by the open trades (at most one per pair), not by the table's history.
  - `[false]` `[reject]` a counter racing the job could expire the trade for its former proposer — CounterTrade refuses a trade past `expires_at` under the lock, and ExpireTrade re-checks the party under the same lock (`:not_allowed`, ignored by the job).
  - `[false]` `[reject]` cancel/decline could act on a trade whose roles a concurrent counter swapped — CloseTrade now re-checks `turn` after `Trade.lock.find`; covered by "after a counter the turn is the other player's" and the accept/counter/cancel race test.

## Verification

**Commands:**
- `bin/rails test test/packs/game` (PARALLEL_WORKERS=2, lane test DB) -- expected: green
- `bin/rails test` (non-system) -- expected: green
- `bin/rubocop` on changed Ruby files, `bin/packwerk check`, `bundle exec i18n-tasks missing` -- expected: no offences

## Auto Run Result

- **Summary:** `Game::AcceptTrade` swaps both sides in one transaction (expiry, turn, friendship and free requested copies checked under AD-10's locks; offer unreserved; `last_gained_at` set where a player's copies rise), `Game::CounterTrade` replaces both sides on the same row, moves the reservation, swaps proposer and recipient and restarts the 7 days, `Game::ExpireTrade` and the recurring `Game::ExpireTradesJob` (every minute) close due trades one per transaction. Events `TradeAccepted`, `TradeCountered`, `TradeExpired`.
- **Files:**
  - `packs/game/app/operations/game/accept_trade.rb`, `counter_trade.rb`, `expire_trade.rb` -- the three operations.
  - `packs/game/app/operations/game/trade_steps.rb` -- steps shared by the trade operations (extracted from ProposeTrade).
  - `packs/game/app/operations/game/propose_trade.rb`, `close_trade.rb` -- use the shared steps; CloseTrade re-checks the party under the lock and has the expiry hooks.
  - `packs/game/app/models/game/trade.rb` -- `due(now)` scope, `expired?(now)`.
  - `packs/game/app/events/game/trade_{accepted,countered,expired}.rb` -- events.
  - `packs/game/app/jobs/game/expire_trades_job.rb`, `config/recurring.yml` -- the recurring expiry.
  - `config/locales/{en,fr}.yml` -- `trade_expired`, `requested_cards_unavailable`, `trade_not_expired`.
  - `test/packs/game/trade_accept_counter_expire_test.rb`, `test/packs/game/trade_concurrency_test.rb` -- tests.
- **Review:** 0 patches; 1 deferred (SetCompleted, low); 3 rejected as false (reasons in the triage log).
- **Follow-up review recommended:** false (no patched entries).
- **Verification:** `bin/rails test` (non-system, PARALLEL_WORKERS=2): 1450 runs, 0 failures, 0 errors; trade concurrency file run 3 times green; `bin/rubocop` on changed files: no offences; `bundle exec packwerk check`: no offences; `bundle exec i18n-tasks missing`: none. No frontend or screen change, so no typecheck, vitest or system test.
- **Residual risks:** none known beyond the deferred SetCompleted; the "every minute" schedule and the error copy are autonomous choices for the author to confirm.
