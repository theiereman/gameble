---
title: 'Staff see accounts that open or trade like an alt account'
type: 'feature'
ticket: '41.7'
created: '2026-11-10'
status: 'in-review'
baseline_revision: '265e0e12dbfb5ca554ea98ff0231161bb96e563d'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-prices-economy-health-and-opening/epic-prices-economy-health-and-opening.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Staff have no way to see accounts that farm capsules or pass cards one way, the first signs of alt accounts feeding a main one. Epic requirements R16 and R17.

**Approach:** A nightly housekeeping operation replaces `game_market_alt_signals` with the account and trade signals that `AltSignals` detects; a staff-only back-office page lists one row per account and signal with its facts as a sentence and a link to the account's player row. It changes nothing on any account.

## Boundaries & Constraints

**Always:**
- Thresholds are constants of `Game::Market::AltSignals`; the detection reads the opened packs and the accepted trades, never the clock, taking `now`.
- `RefreshAltSignals` is an `ApplicationOperation` with no event; one transaction deletes every row and inserts the detected ones, so a failed run keeps yesterday's rows.
- The page is a GET with a Pundit policy open to staff, on the reading role: no write, no database id, no `style` attribute, no IP and no device fingerprint stored or shown. The player link carries the token.
- A deleted account's rows go with it (`ReleasePlayer`), as the privacy page will say rows are replaced every day.
- Copy in `en.yml` and `fr.yml`; every fact is a structured value rendered into a locale-key sentence without plural forms.

**Never:** a sanction, a ban or a flag written on an account; a signal shown to a player or put in a player's export; a new button next to the existing ban; the market signals (story 8).

**Decisions (settled by Claude, no approval round in this batch; the author may revisit):**
- Near-maximum opening: 120 capsules or more opened in a UTC day on at least 3 of the last 7 complete UTC days. Facts: days over, peak day.
- One-way trades: cards never change hands one way, so a side cannot be empty; a trade counts as one-way when one side gives at least 4 times as many copies as it gets. A pair signal: 10 or more such accepted trades in 7 days from the same giver to the same receiver; the row is the giver's and names the receiver. Facts: trades, copies given, copies received.
- The detectors are separate queries under `AltSignals`, each returning `Detected` values, so story 8 adds its own beside them.
- `signal` is a string validated in the model, not a database check, so the next story adds signals with no constraint change.
- The player link opens the players page filtered to that one token (`?player=<token>`), where the existing ban and unban apply; banned accounts stay listed, marked as banned.
- The job runs at 00:40 UTC, after the 00:10 reconciliation, in the development and production blocks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Opening at the edge | 120 capsules on 3 days / 119 on 3 days / 120 on 2 | A row for the first only | No error expected |
| One-way at the edge | 10 trades giving 4 for 1 / 9 / 10 giving 3 for 1 | A row for the first only, naming the receiver | No error expected |
| Yesterday's row | Account no longer matching | Row dropped by the refresh | No error expected |
| Nothing detected | No match | The table is emptied; the page says so | No error expected |
| Players and trades | Any run | No account, trade or holding changes | No error expected |
| A player | Signed in, not staff | The back-office refusal | Routing error as the other pages |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/refresh_edition_prices.rb`, `jobs/game/reconcile_wallets_job.rb` -- models of the housekeeping operation and job.
- `app/controllers/back_office/market_health_controller.rb`, `app/policies/back_office/market_health_policy.rb`, `app/views/back_office/markets/_navigation.html.erb` -- models of the page and its navigation.
- `app/controllers/back_office/players_controller.rb`, `app/domains/accounts/app/queries/accounts/player_search.rb` -- the players page that gains the token filter.
- `app/domains/game/app/operations/game/release_player.rb` -- drops the rows of a deleted account.
- `config/recurring.yml`, `config/routes.rb`, `config/locales/en.yml`, `fr.yml`, `config/i18n-tasks.yml`.

## Tasks & Acceptance

**Execution:**
- [ ] Migration, `Game::Market::AltSignal` model
- [ ] `AltSignals` with the opening and one-way detectors, `RefreshAltSignals`, `RefreshAltSignalsJob`, recurring entries, `ReleasePlayer` cleanup
- [ ] `AltSignalRows` query, policy, route, `BackOffice::MarketSignalsController`, view, navigation entry, players token filter
- [ ] Copy in both locales
- [ ] Tests: detectors at their edges, replacement, nothing else changed, controller, one system test

**Acceptance Criteria:**
- Given players seeded with 130 capsules a day and with one-way trades, when the job has run, then staff see both rows with their facts and reach the account from the link; a player gets the back-office refusal.

## Implementation Notes

Built as planned; nothing was run. `AltSignals` holds the thresholds and a `Detected` value, with `CapsuleOpening` and `OneWayTrades` as nested queries; `RefreshAltSignals` replaces the table in one transaction and `RefreshAltSignalsJob` runs at 00:40 UTC. The page is `BackOffice::MarketSignalsController` at `back-office/market/signals`, one table row per account and signal, each sentence rendered by `AltSignalSentenceComponent`. The players page accepts `?player=<token>` to show one row, which is where each account link leads. `ReleasePlayer` drops the rows naming a deleted account. The sentences and signal names are dynamic keys, ignored as unused by `config/i18n-tasks.yml`. The migration is `20261110200000`; `db/schema.rb` is regenerated at the end.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
