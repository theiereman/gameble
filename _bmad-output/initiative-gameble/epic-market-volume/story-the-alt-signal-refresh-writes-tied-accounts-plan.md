---
title: 'The alt-signal refresh writes tied accounts'
type: 'feature'
ticket: '5'
created: '2026-11-20'
status: 'built'
baseline_revision: '392e76600b0e8b71c66729156a27a3323e2ffb7e'
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

**Problem:** The pair signals (one-way trades, sales outside price, minimum-price sales) tie two accounts, but the tie is only computed in memory for `bids_on_tied_seller`; nothing stores it, so the order form's best visible order (a later entry) has no tie to read, and staff cannot see the ties.

**Approach:** A new `game_market_tied_accounts` table (one row per pair and signal, `low_account_id < high_account_id` checked, unique on pair and signal, with the signal's facts and the refresh time). `Game::Market::RefreshAltSignals` replaces it in the same transaction as `game_market_alt_signals`, from the pair signals it already detected (deleted accounts already dropped by `AltSignals`). When both directions of one pair raise the same signal, the tie row's facts are the two signals' facts summed key by key (every pair-signal fact is a count). `Game::Market::TiedAccounts.call(player)` returns the ids of the accounts tied to a player, server-side only. The back-office signals page adds a "Tied accounts" table: the two accounts, the signal label and a direction-neutral sentence of the facts. `ReleasePlayer` deletes the tie rows naming a deleted account; the delete dialog's table coverage test names the new table with the alt signals' phrase.

</intent-contract>

## Tasks & Acceptance

**Acceptance Criteria:**
- Given ten one-way trades from the higher-id account to the lower-id one, when the refresh runs, then one tie row exists with the lower id first, signal `one_way_trades` and the signal's facts.
- Given a pair whose one account is deleted, when the refresh runs, then no tie row names it.
- Given tie rows from yesterday, when the refresh runs again, then only today's ties remain, refreshed at the new time.
- Given a tie, when `TiedAccounts` reads either account, then it returns the other.
- Given a tie row with `low_account_id >= high_account_id`, when it is inserted, then the database refuses it.
- Given ties, when staff open the signals page, then each tie shows its two accounts, signal and facts; a player gets the unknown address.

## Implementation Notes

Oneshot: about a hundred lines across a migration, a model, a query, the refresh, the page and its strings, all following the existing alt-signal files.

- Columns `low_account_id` / `high_account_id` (as `game_trades`' `low_player_id` / `high_player_id`); the unique index on pair and signal leads with `low_account_id`, so that column has no index of its own.
- `AltSignals::TYING` names the three pair signals that tie; `TiedAccount` validates against it. `bids_on_tied_seller` reads ties and makes none.
- The tie table renders with direction-neutral sentences (`back_office.market_signals.tie_sentences.*`), since a summed both-ways tie has no one actor; `AltSignalSentenceComponent` takes `tie: true` to pick them.
- The delete dialog's table-coverage test names `game_market_tied_accounts` with the alt signals' existing phrase, so the dialog copy is unchanged.
- Surprise: French copy needs U+202F before `:` (`test/config/french_typography_test.rb`).

## Plan Change Log

## Review Triage Log

### 2026-11-20 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The system test clears `AltSignal` in setup and teardown but not `TiedAccount`, which its refresh job now writes — patched: `TiedAccount.delete_all` beside both calls.
  - `[low]` `[patch]` "the page writes nothing" counts no `TiedAccount` rows though the page now reads them — patched: the count includes `TiedAccount.count`.

## Verification

**Commands:**
- `bin/rails test test/domains/game/market/refresh_alt_signals_test.rb test/controllers/back_office/market_signals_controller_test.rb test/controllers/accounts_controller_test.rb` -- expected: green
- `bin/rails test test/system/back_office_market_signals_test.rb` -- expected: green
- `bin/ci`, `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- expected: green

## Auto Run Result

**Summary:** `game_market_tied_accounts` (pair and signal, lower id first, checked, unique) is replaced by `RefreshAltSignals` in the alt signals' transaction from the pair signals it detected (deleted accounts already dropped); both-ways facts add up. `Game::Market::TiedAccounts.call(player)` returns the tied account ids, server-side. The back-office signals page lists the ties with their facts; `ReleasePlayer` deletes a deleted account's ties.

**Files changed:**
- `db/migrate/20261120183000_create_game_market_tied_accounts.rb` -- the table, its check and unique index
- `db/schema.rb` -- regenerated from the migrations
- `app/domains/game/app/models/game/market/tied_account.rb` -- the model
- `app/domains/game/app/queries/game/market/tied_accounts.rb` -- the accounts tied to a player
- `app/domains/game/app/queries/game/market/alt_signals.rb` -- `TYING`, the signals that tie
- `app/domains/game/app/operations/game/market/refresh_alt_signals.rb` -- writes the ties in its transaction
- `app/domains/game/app/operations/game/release_player.rb` -- deletes the ties naming a deleted account
- `app/domains/game/app/queries/game/market/alt_signal_rows.rb`, `app/controllers/back_office/market_signals_controller.rb`, `app/views/back_office/market_signals/show.html.erb`, `app/components/alt_signal_sentence_component.rb` -- the tied accounts table
- `config/locales/en.yml`, `config/locales/fr.yml`, `config/i18n-tasks.yml` -- its strings
- tests: `test/domains/game/market/refresh_alt_signals_test.rb`, `test/controllers/back_office/market_signals_controller_test.rb`, `test/controllers/accounts_controller_test.rb`, `test/components/alt_signal_sentence_component_test.rb`, `test/system/back_office_market_signals_test.rb`

**Review:** quick lens, 2 low findings, both patched; nothing deferred or rejected. Patched by verdict: high 0, medium 0, low 2.

**Follow-up review recommended:** false.

**Verification:** the touched unit, controller, component tests and `test/system/back_office_market_signals_test.rb` green; `bundle exec packwerk check` and `bin/rails zeitwerk:check` clean; `bin/ci` before commit failed only on the schema round trip (uncommitted `db/schema.rb`, which its `git diff --exit-code` reads) and on French typography, since fixed; rerun after commit.

**Residual risks:** `db/schema.rb` will collide with the sibling lanes' migrations at merge and must be regenerated.
