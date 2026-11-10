---
title: 'Refactor sweep'
type: 'refactor'
ticket: '38.13'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: '79ae74e130da086af8cfc20079eaf4fae2f36186'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The epic's stories 1 to 12 were built one after another, each copying the shape of the one before, so duplicated code now sits in the market operations and the back-office market controllers. The build records and the reviews of those stories deferred no finding, so the scope is what a read of the landed code shows.

**Approach:** Behaviour-preserving cleanup only: extract each duplicate into one named place, run a static audit for dead code in the market files, and leave everything else as built. Anything that needs new behaviour, a new screen or a schema change is a new story, not part of this one.

## Boundaries & Constraints

**Always:** Every operation keeps its signature, its `Success` or `Failure(:code)` values, its transaction, its lock order and its published event, so existing tests pass unchanged. Locale keys stay as they are. Intent is carried by names, with no new comments beyond the one-line comment the extracted modules already follow.

**Never:** No schema or migration change. No new setting, route, screen, string or event. No change to the shared fixtures (`entrust_preview_cases.json`, `picoin_forms.json`). Do not touch `db/schema.rb`, the ticket files, other plans or `config/*.key`. Do not rename a failure code or an event. Do not merge the two controllers' `refusal_line` methods: their cases differ and dynamic locale keys would hide unused keys from `i18n-tasks`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Non-administrator changes or opens | player is a moderator or an ordinary player | `Failure(:administrator_required)` from both `ChangeSettings` and `OpenMarket`, before any write | Same as before |
| Settings change published | any of `CreateFirstSettings`, `OpenMarket`, `ChangeSettings` succeeds | one `SettingsChanged` with `settings_id` on stream `Game::Market$settings`, inside the transaction | Same as before |
| Refused back-office save | closing or settings POST refused | same 422 re-render and refusal line as before | Same as before |

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/change_settings.rb` -- holds a private `require_administrator` and publishes `SettingsChanged` with an inline stream name.
- `app/domains/game/app/operations/game/market/open_market.rb` -- byte-identical `require_administrator` and the same inline publish.
- `app/domains/game/app/operations/game/market/create_first_settings.rb` -- third inline `SettingsChanged` publish.
- `app/domains/game/app/operations/game/market/announces_change.rb` -- the existing shared module of the two administrator operations; the model for the new one.
- `app/domains/game/app/events/game/market/settings_changed.rb` -- the event; the natural owner of its stream name and its data shape.
- `app/controllers/back_office/market_closings_controller.rb`, `market_settings_controller.rb` -- each carries the same "permit a nested param hash or return `{}`" method.
- `app/controllers/concerns/back_office/market_page.rb` -- the concern both controllers (and the openings one) already include; home for the shared permit method.
- `app/helpers/market_entrustments_helper.rb`, `app/frontend/lib/entrust*.ts`, `app/domains/game/app/queries/game/market/*` -- scanned by the audit task for dead code.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/events/game/market/settings_changed.rb` -- add `STREAM = "Game::Market$settings"` and `self.about(settings)` returning the event with `{ settings_id: settings.id }` -- one place for the name and data shape
- [ ] `app/domains/game/app/operations/game/market/create_first_settings.rb` -- publish with `SettingsChanged.about(settings)` and `SettingsChanged::STREAM` -- drop the inline copy
- [ ] `app/domains/game/app/operations/game/market/requires_administrator.rb` -- new module `Game::Market::RequiresAdministrator` with the private `require_administrator(player)` -- shared by both administrator operations, same style as `AnnouncesChange`
- [ ] `app/domains/game/app/operations/game/market/change_settings.rb` -- include `RequiresAdministrator`, delete the local method, publish through `SettingsChanged.about` and `STREAM` -- remove duplication
- [ ] `app/domains/game/app/operations/game/market/open_market.rb` -- same change as `ChangeSettings` -- remove duplication
- [ ] `app/controllers/concerns/back_office/market_page.rb` -- add private `submitted_params(key, *permitted)` returning the permitted hash as symbolized keys, or `{}` when the nested value is not a hash -- the one parsing rule
- [ ] `app/controllers/back_office/market_closings_controller.rb`, `app/controllers/back_office/market_settings_controller.rb` -- replace `submitted_closing` and `submitted_settings` by calls to `submitted_params` -- remove duplication
- [ ] `app/domains/game/app/queries/game/market/`, `app/helpers/`, `app/frontend/lib/`, `app/frontend/controllers/` -- audit the market files for unused methods, constants, exports and locale-free leftovers with grep, and delete only what has no caller in `app`, `test` or `config` -- dead code recorded by the build
- [ ] `test/domains/game/market/change_settings_test.rb`, `test/domains/game/market/open_market_test.rb`, `test/domains/game/market/create_first_settings_test.rb` -- assert the published `SettingsChanged` carries the settings id on `SettingsChanged::STREAM`, and that a moderator gets `administrator_required`, where not already asserted -- pins the extracted behaviour

**Acceptance Criteria:**
- Given the extraction is done, when the sources of `ChangeSettings` and `OpenMarket` are read, then neither defines `require_administrator` nor spells the stream name.
- Given a successful opening, change or first version, when the event store is read, then one `SettingsChanged` exists on `Game::Market$settings` with the new version's id.
- Given a refused closing or settings save, when the page re-renders, then the status, form values and refusal line match what the controller tests already assert.
- Given the sweep is finished, when `git diff` is read, then no locale, schema, route, fixture or ticket file changed.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Decisions settled in planning (no human checkpoint in this run):

- Scope is derived from the code, since no build record or review of stories 1 to 12 deferred a finding (each review note reads "no defect found").
- The administrator check becomes a module beside `AnnouncesChange` rather than a method on `Operation`, because only the two market administrator operations need it and `Accounts` operations return plain symbols, not `Failure`.
- The stream name lives on the event, not on `Operation`, because three operations publish the same event and nothing else uses the stream.
- Refusal lines stay per controller (see Never); only the identical parsing method is shared.
- No JavaScript, CSS or view change: the largest market file (`card-detail.css`, 489 lines) stays under its 500-line limit and its market addition is 14 lines.

## Verification

**Commands:**
- `bundle exec rubocop <touched files>` -- expected: no offences
- `bundle exec packwerk check` -- expected: no violations
- `bin/rails zeitwerk:check` -- expected: all is good
- `script/check_planning_references && script/check_file_sizes` -- expected: no output
- `bin/ci`, `npm run test:js`, then `bin/rails test test/domains/game/market test/controllers/back_office` and the market system tests (`test/system/market_entrust_test.rb`, `back_office_market_test.rb`, `market_suspension_test.rb`, `market_rules_pages_test.rb`) -- expected: pass, run once at the end of the market build
