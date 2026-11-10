---
title: "An administrator changes the economy settings with the Brotherhood's announcement"
type: 'feature'
ticket: '9'
created: '2026-11-10'
status: 'ready-for-dev'
baseline_revision: 'fba34210796de7c1e7100c0e01d9f1ae5f13a63c'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/story-an-administrator-opens-the-market-from-the-back-office-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The economy values are fixed at the starting version; no administrator can tune a stamp, a minimum, the cap or any rule without a deployment, and nothing guards a typing error or a sale at a loss.

**Approach:** `Game::Market::ChangeSettings` validates a whole candidate row against the version the form drew (`SettingsRules`), inserts the next version through `Settings#successor`, announces it through `AnnouncesChange` and publishes `SettingsChanged`, all in one transaction. The back-office Marché page gets the settings form (a table per rarity, single fields for the rest), refusals beside each field, administrators saving and moderators reading. Epic requirements R15 (change side), R18, R19, R20.

## Boundaries & Constraints

**Always:** administrators only for the operation and the POST; moderators see every value read-only with the reason; the form submits the token of the version it drew (never an id), and no form exists when there is no version (see the first-opening decision) and a stale token, or a lost insert race (`RecordNotUnique` on `replaces_id`), is `Failure(:settings_changed)` shown as "Un autre administrateur vient de modifier les réglages." with typed values kept; the candidate is a whole row of the editable columns, validated as a whole, every violation reported at once; the new version copies `open`, both confirmation times and `first_opened_at` from the current one and records the author; one `SettingsChanged` published inside the transaction, heard by nobody; the announcement in both languages is required and a refused announcement rolls the whole change back; a GET never writes; no id in URLs, HTML or DOM; every string in `en.yml` and `fr.yml`, `errors.game.<code>` added by hand; no inline style; CSS under 500 lines per file.

**Never:** closing or opening the market (stories 2 and 10; `open` and the confirmations are not editable here), the alerts' "Préparer ce changement" and "Ignorer" (epic 41), a cached settings read, a second writer of settings rows, a change to the first version's starting values, a migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid change | administrator, current token, candidate within bounds, both messages | new version replacing the current one, author set, `open` and first opening copied, announcement shown, `SettingsChanged` | none |
| Amount at an edge | an amount, minimum or the cap at exactly twice or exactly half the current value | accepted | none |
| Beyond an edge | one past double, or below half (rounded up) | nothing written | `invalid_settings`, violation `more_than_double` or `less_than_half` beside the field |
| No-loss floor | a minimum below `ceil100((entrustment + stamp) / (1 - commission))` of the candidate's own values | nothing written | violation `below_floor` naming the floor amount |
| Stamp raised alone | Rare stamp raised, minimum left | refused by the floor when it falls under; accepted with the raised minimum | as above |
| Commission | 0% and 25% accepted; 25.01% and negative refused | as stated | violation `out_of_range` |
| Other ranges | durations, increment, soft close, counts, window, thresholds, alert thresholds, income targets at and beyond their ranges | at the edge accepted | violation `out_of_range`, `durations_not_ascending`, `preselected_not_a_duration` |
| Optional fields | the three alert thresholds and the five income targets blank | stored null (an alert with no threshold is off) | none |
| Required fields | every other editable field blank | nothing written | violation `not_a_number` beside the field |
| Comma or dot | `12,5` or `12.5` typed for a percent or a day target | the same value, 12.5% or 12.5 days | none |
| Unparseable text | `abc`, `1 2 x`, `12.5` in an integer field | nothing written, raw text re-rendered | violation `not_a_number` beside the field |
| No version yet | the market was never opened, so no settings row exists | page draws a hint and no form | POST fails `settings_changed`, re-renders the hint with 422 |
| Missing announcement | a language empty or over length | nothing written | `invalid_announcement` |
| Stale form | token of an older version | nothing written | `settings_changed` |
| Not an administrator | moderator, player, banned | nothing written | `administrator_required` |
| Deadlock | `ActiveRecord::Deadlocked` | rolled back | `market_busy` |
| Moderator on the page | GET | every value shown, all controls disabled, reason text | POST refused by policy |

## Decisions

- Operation shape: `call(player:, settings_token:, candidate:, message_fr:, message_en:)`; `candidate` is a hash over `SettingsRules::EDITABLE`, every editable column of the row; anything else is dropped, so `open`, confirmations, author and replaces can never be set by a form.
- Validation lives in a pure `Game::Market::SettingsRules` (candidate and current row in, violations by field out). The operation fails `:invalid_settings` on any violation; the controller asks the same rules for the per-field messages to draw, so no new failure payload shape is needed.
- Ratio bound for amounts, minimums and the cap: new value at most twice and at least half (rounded up) of the current value, and above zero. Entrustment, stamp and minimum are checked per rarity against that rarity's current value.
- No-loss floor uses the candidate's entrustment, stamp and commission, in integers: `ceil(10000 * (entrustment + stamp) / (10000 - commission_bp))` rounded up to the next hundred; each minimum must be at or above it. The floor is named in the refusal.
- Ranges proposed for the author's approval (none is bounded by `market-economy.md`): commission 0 to 2500 basis points (0% to 25%, as spec); increment 100 to 2000 bp (1% to 20%); each of the three durations 1 to 720 hours, strictly ascending short < medium < long, the preselected one among the three (matches the table's check); soft close 30 to 900 seconds; average sale count 3 to 20 (never under the few-sales constant 3); average window 7 to 365 days; feed threshold multiple 2 to 100; unusual maximum multiple 2 to 20; the three alert thresholds optional (destroyed share 0 to 10000 bp, picoins per player above zero, top share 1 to 10000 bp, see the optional-fields decision); income-day targets optional, 0.001 to 365 days.
- Targets for the day of income get no starting value here (the first version stays untouched and the columns are nullable); epic 41's indicators say "not enough data" until an administrator sets them. The form shows them blank-able.
- Percent columns (commission, increment, alert shares) are typed in percent and converted to basis points by the form object as the parsing contract below states.
- The page's stale-save message is the dedicated line "Un autre administrateur vient de modifier les réglages." (`back_office.market_settings.stale` in both locales), not the generic `errors.game.settings_changed` text, which stays for operations reached elsewhere.
- Failed saves re-render the Marché page with 422 and the typed values, the current version's values shown next to a stale refusal so the administrator can redo the change; success redirects with a notice (303).
- Table layout: three rows (entrustment pays, stamp, minimum price) by five rarity columns, plus the income-target row; each input is named by its row and column headers through `aria-labelledby`, its bound and moment of application in a hint read through `aria-describedby`, and its refusal in an element with `role="alert"` beside it with `aria-invalid`.
- When each setting applies is stated as text per group: entrustment values and the cap at once; stamp and minimum at listing; durations, increment, soft close, unusual maximum at an auction's creation; commission at close; average count and window, feed threshold at once.
- The form draws from a `SettingsForm` value object built from a settings row, so epic 41 prefills it by building the object from another source; this story adds no prefill input.
- Moderators reach the page read-only (epic assumption); the opening section stays as story 2 left it, below the settings section.
- No version yet: `CurrentSettings.call` is nil until `OpenMarket` inserts the first row. The settings section then renders only its heading and the hint "The economy settings become editable once the market has been opened for the first time." (`back_office.markets.settings.not_yet_open`); `@settings_form` is nil, no token, no inputs, no announcement fields, no submit, for administrators and moderators alike. `ChangeSettings` with no current row fails `settings_changed` (nothing to change from), and the controller then re-renders the page with the hint and 422. The opening section is untouched and still appears below.
- Parsing contract, owned by `BackOffice::MarketSettingsForm` and read by the rules: a typed value is stripped of all whitespace (including the no-break spaces French typing inserts in thousands). Blank is `nil`. Integer columns (amounts, minimums, cap, hours, seconds, counts, multiples, alert picoins per player) accept `-?\d+` and become `Integer`. Percent columns (commission, increment, the two alert shares) accept `-?\d+([.,]\d+)?`, are read as a decimal with either separator and become `Integer` basis points, `(percent * 100)` rounded to the nearest basis point. Day targets accept the same decimal shape and become `BigDecimal` rounded to 3 places. Any other text, or a decimal in an integer column, is kept as its raw `String` in the candidate. So a candidate value is `Integer`/`BigDecimal` when parsed, `nil` when blank, a `String` when unparseable.
- Rules over that contract: a required field whose value is not an `Integer` (nil or String) gives `not_a_number` and no other violation for that field; an optional field (see next decision) that is `nil` is valid, a `String` gives `not_a_number`; a day target that is neither nil nor `BigDecimal` gives `not_a_number`. Only parsed values reach the ratio, floor and range checks, and a field already `not_a_number` is skipped by the floor (the floor is not computed when its entrustment, stamp or commission is unparsed, and the minimum then shows no floor violation, only its own). A negative parsed value is a range or ratio violation, never `not_a_number`.
- Optional fields, decided: all three alert thresholds (`alert_destroyed_share_basis_points`, `alert_picoins_per_player`, `alert_top_share_basis_points`) and the five income targets are optional because their columns are nullable; blank stores null and means that alert or indicator is off. The destroyed share keeps its starting value 4000 on the first version and the range 0 to 10000 bp when filled; picoins per player is above zero up to 1_000_000_000_000; top share 1 to 10000 bp. Every other editable column is required.
- Re-rendered form, token and bounds: the form always holds `token`, `settings` (the row its bounds, "currently" hints and moments are computed against) and `raw` (the typed text per field). On `invalid_settings` it keeps the submitted token and is drawn against the row found by that token (`Game::Market::FindSettings.call(token)`), which is the row the operation validated against, with the typed raw text of every field kept and each refused field showing its violation. On `settings_changed` it carries the new current token and is drawn against the new current row, so the typed text is kept, every "currently" hint shows the amounts now in force, the stale line is at the top, and resubmitting validates against the new version. On success it redirects and the page is drawn afresh from the new current. A form with an unknown or blank token on a POST is treated as stale.
- Placement: the settings section renders regardless of the open state, outside the `unless @state.open?` block of `show.html.erb`, because a change is allowed while the market is open and the live economy is what R15 concerns; only the opening section stays inside that closed-only block. Two sections therefore share a page whenever the market is closed, so nothing may be shared. The announcement partial takes `dom` (id prefix), `scope` (nil keeps the top-level `message_fr`/`message_en` names the opening form posts; the settings form passes `market_settings` and posts `market_settings[message_fr]`, `market_settings[message_en]`), `legend` and `reason_id`. Settings uses dom `market-settings-announcement` (ids `market-settings-announcement-fr`/`-en`), opening keeps `market-announcement`. Each section is its own `<form>`, so each posts only its own fields. Each section has an id (`market-settings`, `market-opening`) and an accessible name from its heading (`aria-labelledby`): "Economy settings" and the existing opening heading; the settings announcement legend reads "Announcement of this change", the opening one keeps its legend. Moderator reasons use distinct ids (`market-settings-reason`, `market-opening-reason`).
- Failure lines on the settings page, each drawn in one `<ul class="ledger-errors" role="alert">` at the top of the settings form (the `refusal` line of `MarketSettingsForm`) with a 422, never a flash: `invalid_settings` shows the summary `back_office.market_settings.invalid` ("Some settings were refused. Check the marked fields.") above the per-field alerts; `settings_changed` shows `back_office.market_settings.stale`; `invalid_announcement` shows the dedicated `back_office.market_settings.announcement_refused` ("Each announcement needs text in both languages, at most 280 characters. The settings were not changed."), because `errors.game.invalid_announcement` ends with "The market was not opened." which is false here and stays untouched for the opening page; `administrator_required`, `market_busy` and `player_required` show `ChangeSettings.failure_message(code)` (the existing `errors.game.*` lines, none of which mention opening). A small private `refusal_line(code)` in the controller owns this mapping.
- Typed announcement survives a refusal: `MarketSettingsForm` also holds `message_fr`, `message_en` (from `market_settings[message_fr]`, `market_settings[message_en]`, blank on a fresh page) and `refusal` (the line above, nil on a fresh page). The `_settings` partial passes `message_fr`/`message_en` from the form to the announcement partial, which reads them from any object answering those two methods (the opening's `Opening` or the form), so every refused save keeps both fields.
- Settings candidate params travel under `market_settings[...]` with the token as `market_settings[token]`; only `SettingsRules::EDITABLE` keys plus `token`, `message_fr` and `message_en` are read, as a strict allow-list, so the form posts nothing else.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/settings.rb` -- insert-only row; `successor(author:, **changes)` copies everything except id, token, author, replaces, created time and carries `open`, confirmations and first opening.
- `app/domains/game/app/operations/game/market/open_market.rb`, `announces_change.rb` -- the shape to follow: administrator check, one transaction, `RecordNotUnique` to `settings_changed`, `announce`, `publish(SettingsChanged..., stream_name: "Game::Market$settings")`, `Deadlocked` to `market_busy`.
- `app/domains/game/app/queries/game/market/current_settings.rb`, `entrust_cards.rb` -- current version read every time; entrusting already refuses a stale token with `amounts_changed`, so no change there.
- `app/domains/game/app/models/game/market/starting_settings.rb` -- the column names and the starting values.
- `db/migrate/20261110090000_create_game_market_tables.rb` -- columns, nullability and checks (commission 0 to 2500, preselected among the durations) that the rules must agree with.
- `app/controllers/back_office/{markets,market_openings}_controller.rb`, `app/policies/back_office/market{,_opening}_policy.rb` -- the Marché page, the `Opening` data object and the 422 re-render pattern to mirror.
- `app/views/back_office/markets/{show,_opening,_announcement}.html.erb`, `app/views/back_office/announcements/_fields.html.erb` -- the announcement fieldset takes `opening:` and `disabled:` and hardcodes dom `market-announcement`, the reason id `market-opening-reason` and top-level param names; `_fields` takes `dom:` and hardcodes `message_fr`/`message_en`. Both gain `scope`, `legend` and `reason_id` locals so the two sections never share ids or names.
- `app/domains/game/app/queries/game/market/current_settings.rb` -- nil until `OpenMarket` inserts the first row (`StartingSettings` is only applied there), so every reader of the settings must handle nil.
- `app/helpers/picoins_helper.rb`, `app/components/picoin_amount_component.rb` -- exact amounts in hints and refusals.
- `config/routes.rb` (back-office scope, `resource :market_opening`), `config/locales/{en,fr}.yml` (`back_office.markets.*`, `errors.game.*`), `app/frontend/styles/back-office-market.css`.
- `test/support/market.rb` (`open_market!`, `close_market!`), `test/domains/game/market/open_market_test.rb`, `test/system/back_office_market_test.rb`, `test/system/market_entrust_test.rb`, fixtures `accounts_players(:administrator|:moderator|:player)`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/settings_rules.rb` -- new pure object: `EDITABLE` columns, `SettingsRules.new(current).violations(candidate)` returning `{ field => Violation(code, values) }`; the candidate holds `Integer`/`BigDecimal` for parsed values, `nil` for blank and a raw `String` for unparseable text; `REQUIRED` and `OPTIONAL` field lists (the three alert thresholds and five income targets are optional); required non-Integer gives `not_a_number`, optional nil is valid, optional String gives `not_a_number`; then the ratio bound, no-loss floor (skipped when its inputs are unparsed), ranges, ascending durations, preselected among durations; `floor(entrustment, stamp, commission_bp)` public -- one place for every bound, read by the operation and the form
- [ ] `app/domains/game/app/queries/game/market/find_settings.rb` -- new query `FindSettings.call(token)`: the version with that token or nil -- lets the controller redraw a refused form against the version the operation validated, without reading a model
- [ ] `app/domains/game/app/operations/game/market/change_settings.rb` -- `call(player:, settings_token:, candidate:, message_fr:, message_en:)`: administrator check, then in one transaction read current, refuse a token mismatch, a blank token or no version with `settings_changed`, `invalid_settings` on any violation, insert `current.successor(author: player, **candidate.slice(*EDITABLE))`, rescue `RecordNotUnique` as `settings_changed`, `announce`, publish `SettingsChanged`, rescue `Deadlocked` as `market_busy`; returns the new row -- the change itself
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.invalid_settings` plus the dedicated page strings (below) in both files, by hand
- [ ] `app/models/back_office/market_settings_form.rb` -- value object from a settings row (`from_settings`) or submitted params plus a row (`from_params`): `settings`, `token`, `raw` typed text per field, `candidate` per the parsing contract (whitespace stripped, comma or dot decimal for percents and day targets, percent to basis points rounded to the nearest, blank nil, unparseable kept as String), `message_fr`, `message_en` and `refusal` (so a refused save redraws the typed announcements and shows its one line), `value_for(field)` returning the raw text when typed else the row's value formatted for display (percent with a dot, integers plain), `violations` through `SettingsRules` against its own row -- what the page draws and the controller submits
- [ ] `config/routes.rb` -- `resource :market_settings, path: "market/settings", only: :create` in the back-office scope
- [ ] `app/policies/back_office/market_setting_policy.rb` -- `create?` for administrators (the page itself stays under `MarketPolicy#show?`)
- [ ] `app/controllers/back_office/market_settings_controller.rb` -- create: authorize, rate limit 10 a minute, read `params[:market_settings]` through the `EDITABLE` allow-list, call `ChangeSettings` with its `token`, the form's candidate and both messages; success redirects 303 with a notice; failure re-renders `back_office/markets/show` with 422, sets the form's `refusal` from `refusal_line(code)` (stale for `settings_changed`, `back_office.market_settings.invalid` for `invalid_settings`, `back_office.market_settings.announcement_refused` for `invalid_announcement`, `ChangeSettings.failure_message(code)` for `administrator_required`, `market_busy` and `player_required`; always drawn in the form's `role="alert"` list) and passes the opening data as a fresh `Opening`; every failure branch builds the form with the typed `message_fr`/`message_en`: for `invalid_settings` the form keeps the submitted token and is drawn against `FindSettings.call(token)` with its violations; for `settings_changed` the form carries the current token, is drawn against the current row, keeps the typed text and shows the stale line; with no version at all `@settings_form` is nil and the hint is drawn
- [ ] `app/controllers/back_office/markets_controller.rb` -- show builds `@settings_form` from the current version, or nil when `CurrentSettings.call` is nil (read only); a shared private `settings_form_for_page` keeps the nil case in one place
- [ ] `app/views/back_office/announcements/_fields.html.erb`, `app/views/back_office/markets/_announcement.html.erb`, `_opening.html.erb` -- add `scope`, `legend` and `reason_id` locals with defaults that keep today's output for the opening (dom `market-announcement`, names `message_fr`/`message_en`, reason `market-opening-reason`) and the announcements index unchanged; give the opening section `id="market-opening"`
- [ ] `app/views/back_office/markets/show.html.erb`, `_settings.html.erb`, `_settings_rarities.html.erb`, `_settings_field.html.erb` -- settings section `id="market-settings"` named by its heading, rendered outside the `unless @state.open?` block so it shows with the market open or closed (only the opening section stays inside it), above the opening: with no form (nil), only the heading and the not-yet-open hint, no inputs, token or announcement; otherwise rarity table (row and column headers naming each input), grouped single fields each with bound and moment hints, the announcement fieldset (dom `market-settings-announcement`, scope `market_settings`, its own legend, `market-settings-reason`, values from the form's `message_fr`/`message_en`) with both languages required, the form's `refusal` in a `role="alert"` list at the top, the hidden `market_settings[token]`, refusals beside fields with `role="alert"` and `aria-invalid`, the stale refusal at the top; for a moderator every control disabled with the reason
- [ ] `app/frontend/styles/back-office-market-settings.css`, `app/frontend/entrypoints/application.css` -- table and field layout on existing tokens, narrow-screen scrolling confined to the table; no inline style
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `back_office.markets.settings.*` (heading, `not_yet_open`, `announcement_legend`, headings, row and column labels, hints with bounds and moments, violations `more_than_double`, `less_than_half`, `below_floor`, `out_of_range`, `not_a_number`, `durations_not_ascending`, `preselected_not_a_duration`), `back_office.market_settings.{saved,stale,invalid,announcement_refused}` (the last says the settings were not changed; `errors.game.invalid_announcement` is left as is for the opening page); French stale line "Un autre administrateur vient de modifier les réglages."
- [ ] Tests: `test/domains/game/market/{settings_rules,change_settings,find_settings}_test.rb` (each bound at its edges, `not_a_number` for nil and String on every required field and a String on an optional one, nil valid on the three alert thresholds and five targets including the destroyed share, no version gives `settings_changed`, the floor and the stamp-raised case, open and first opening copied across versions, author recorded, the concurrent save by a version inserted between draw and save, bad announcement rolling back, moderator and player refused, deadlock), `test/policies/back_office/market_setting_policy_test.rb`, `test/models/back_office/market_settings_form_test.rb` (parsing contract: `abc`, blank, `12,5`, `12.5`, `1 000` with spaces and no-break spaces, a decimal in an integer field, negatives, rounding to the nearest basis point, raw text kept for refused fields, token kept), `test/controllers/back_office/market_settings_controller_test.rb` (success; per-field refusal with 422, the raw typed text kept and the submitted token in the hidden field; stale line with the new current token, typed text kept and the "currently" hints on the new amounts; each failure code shows its line in the role=alert list with 422 (`invalid_announcement` shows the settings-specific text, not "The market was not opened"; `administrator_required`, `market_busy`, `player_required`); typed `message_fr`/`message_en` kept after `invalid_settings`, `settings_changed` and `invalid_announcement`; with the market open the form is present and a valid save succeeds; no version: GET and POST both render the not-yet-open hint with no settings form or token and no NoMethodError, the opening section still present; the two sections have no duplicate ids and the settings announcement posts `market_settings[message_fr]`; moderator POST refused; page read-only for a moderator), `test/system/back_office_market_test.rb` -- scope every existing opening step with `within "#market-opening"` (the settings section shows identical labels once the market is closed and a version exists) and add one system test: an administrator raises the Rare stamp and minimum with both announcements, a player sees the announcement, and a Confier form drawn before the save is refused with the new amounts

**Acceptance Criteria:**
- Given an administrator on the Marché page, when the Rare stamp and the Rare minimum are raised within bounds and both announcements typed, then a new version is current, the announcement replaces the one shown, and a Confier form drawn before is refused with the new amounts drawn and the ticks kept.
- Given a minimum below its no-loss floor, when saved, then nothing changes and the refusal beside that field names the floor.
- Given two administrators who opened the page on the same version, when the second saves after the first, then the second sees "Un autre administrateur vient de modifier les réglages." with its typed values kept.
- Given the market is open or closed, when a change is saved, then the new version keeps that state and the first opening time.
- Given a moderator, when the page is opened, then every value is readable, every control disabled and the reason shown.
- Given the market was never opened and no settings row exists, when an administrator or moderator opens the Marché page, then the settings section shows the hint that settings become editable after the first opening, no form and no token, the opening section works as before, and a forced POST re-renders that page with 422 instead of raising.
- Given the market is closed and a version exists, when the page renders, then the settings and opening sections have no duplicate id, each announcement label belongs to the field in its own section, and each form posts only its own fields.
- Given an administrator types `12,5` for the commission, a blank required field and `abc` for a duration, when saved, then nothing is written, the commission is read as 12.5%, the blank and `abc` fields show `not_a_number` beside them with their raw text kept, and the submitted token is still in the form.
- Given the three alert thresholds and the income targets are blank, when saved with other valid changes, then they are stored null; given a required field is blank, then it is refused.
- Given a stale save, when the form is redrawn, then it carries the new current token and the new amounts in its hints with the typed text kept, and resubmitting it succeeds if valid.
- Given any refused save (`invalid_settings`, `settings_changed`, `invalid_announcement`, `administrator_required`, `market_busy`, `player_required`), when the page is re-rendered, then it answers 422 and its line is in the settings form's `role="alert"` list; given `invalid_announcement`, then the line says the settings were not changed and never that the market was not opened.
- Given a refused save, when the form is redrawn, then both typed announcement texts are still in their fields.
- Given the market is open, when an administrator opens the Marché page, then the settings form is present and a valid change saves, while the opening section is absent.
- Given the page, when read with a screen reader, then each table input is named by its row and column headers and its refusal is announced.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The rules object keeps the bounds in one place so the operation enforces them and the page explains them with the same numbers. Sketch of the floor:

```ruby
def floor(entrustment, stamp, commission_bp)
  (10_000 * (entrustment + stamp)).ceildiv(10_000 - commission_bp).ceildiv(100) * 100
end
```

## Verification

**Commands:**
- `bin/rails test test/domains/game/market test/policies/back_office test/models/back_office test/controllers/back_office` -- pass
- `bin/rails test test/system/back_office_market_test.rb` -- pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `npm run format:check`, `npm run lint:css`, `bundle exec i18n-tasks health` -- clean

**Manual checks (if no CLI):**
- In development as Dev Player, raise a stamp without its minimum and read the refusal naming the floor; save a valid change and see the new banner.
