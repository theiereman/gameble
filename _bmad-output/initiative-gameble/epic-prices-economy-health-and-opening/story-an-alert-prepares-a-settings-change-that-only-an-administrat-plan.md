---
title: 'An alert prepares a settings change that only an administrator applies'
type: 'feature'
ticket: '41.6'
created: '2026-11-10'
status: 'built'
baseline_revision: '24beb5709830e77166d8cc9167727d33f5bacbd5'
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

**Problem:** An indicator past its threshold only shows a number; the author must work out the change and its knock-on values by hand. Epic requirement R15.

**Approach:** An alert is derived from an indicator's last point and the current thresholds, with a proposed change computed within the setting bounds. For an administrator, "Préparer ce changement" opens the settings form by a GET with the proposal prefilled, the changed fields marked and focus on the first; nothing is written until the administrator saves with the announcement. "Ignorer" hides the alert in the browser until the value changes.

## Boundaries & Constraints

**Always:**
- Alerts come from `EconomySeries`' last point and the current thresholds, never on a null point and never on a blank threshold; there is no automatic regulation.
- The proposal is recomputed by the server from the alert's name (`?prepare=<indicator>`), never read from the URL, and it passes `SettingsRules` (at most double, the no-loss floor) or the alert carries no action.
- A raised stamp brings its rarity's minimum price up to the no-loss floor in the same proposal.
- The prefill is shown only to an administrator; a moderator sees the alert and its proposal in words, without the action, and the prepared GET shows them the unprepared form.
- The write stays `ChangeSettings` through the existing form with the Brotherhood's announcement; the prepared GET writes nothing.
- "Ignorer" keeps `gameble:ignored-alert:<indicator>` with the value in `localStorage`, read and written inside try/catch; the alert hides while the stored value equals the current one and shows again once it differs.
- Copy in `en.yml` and `fr.yml`; the frame uses the alert colour; no `style` attribute.

**Never:** an alert on days of income, a change written by a GET or a job, a proposal outside the bounds, a value taken from the request.

**Decisions (settled by Claude, no approval round in this batch; the author may revisit; the epic's open question is closed here):**
- Destroyed against created under `alert_destroyed_share_basis_points` proposes the Rare stamp raised by half, rounded up to the next hundred and never above double (2 000 becomes 3 000), with the Rare minimum raised to the floor (7 800 becomes 8 900).
- PiCoins per active player above `alert_picoins_per_player` proposes the same Rare stamp change: money piles up, so more of it is burned.
- Top 1% share above `alert_top_share_basis_points` proposes the Legendary stamp raised the same way: the richest hold the dearest cards.
- Days of income has targets, not thresholds, and the spec starts it without an alert, so it raises none.
- The stored ignore value is the alert's value as text, and an ignored alert loses its frame and its proposal, nothing else.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Share under threshold | Ratio 3 400 bp, threshold 4 000 | Alert with the Rare stamp and minimum proposal | No error expected |
| Null point | Last value null | No alert | No error expected |
| No threshold | Setting blank | No alert | No error expected |
| Proposal out of bounds | Floor above double the minimum | Alert without action | No error expected |
| Administrator prepares | `?prepare=destroyed_share` | Form prefilled, changed fields marked, first focused, version unchanged | Unknown or quiet alert: plain form |
| Moderator | Same URL | Plain form, alert without action | No error expected |
| Ignored | Stored value equals current | Alert hidden; shown again when the value moves | Storage refused: shown |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/queries/game/market/economy_series.rb` -- the points the alerts read (story 5).
- `app/domains/game/app/models/game/market/settings_rules.rb` -- bounds and floor the proposal obeys.
- `app/models/back_office/market_settings_form.rb`, `app/views/back_office/markets/_settings_field.html.erb` -- the form that is prefilled and marks changed fields.
- `app/controllers/back_office/markets_controller.rb` -- reads `prepare`.
- `app/views/back_office/market_health/show.html.erb` -- draws the alert and its action.
- `app/frontend/lib/alert_ignore.ts`, `app/frontend/controllers/alert_ignore_controller.ts` -- the ignore.

## Tasks & Acceptance

**Execution:**
- [ ] `Game::Market::EconomyAlerts` -- alerts and bounded proposals
- [ ] Form `prepared`, changed marks, `MarketsController` prefill for administrators
- [ ] Health page alert frame, proposal, "Préparer ce changement", "Ignorer"; `alert_ignore` lib and controller
- [ ] Copy in both locales, style
- [ ] Tests: unit, controller, Vitest, one system test

**Acceptance Criteria:**
- Given a destroyed share under its threshold, when an administrator presses "Préparer ce changement", then the raised stamp and minimum are prefilled with focus on the first, and leaving without saving keeps the settings version; "Ignorer" hides the alert until the value changes.

## Implementation Notes

Built as planned; nothing was run except one Vitest file by mistake (6 passing). `EconomyAlerts` returns `Alert`s carrying the current and the proposed values of the stamp and minimum; `named` finds one by its indicator's name from `?prepare=`. `MarketsController` builds the prepared form only for an administrator through `MarketSettingsForm#prepare`, which marks the changed fields (`data-prepared`) and puts `autofocus` on the first. The health tile's alert is the `alert` partial, which the `alert-ignore` controller hides and unframes; moderators get the proposal without any button. `config/i18n-tasks.yml` was not touched again: the alert and prepared keys are static.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `ruby -c`, `npx prettier --check`, `npm run lint:css`, `npx tsc --noEmit`, YAML parse and en/fr parity, `script/check_planning_references`, `script/check_file_sizes` -- expected: no finding
