---
title: "An administrator changes the economy settings with the Brotherhood's announcement"
type: 'feature'
ticket: '9'
created: '2026-11-10'
status: 'draft'
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

**Always:** administrators only for the operation and the POST; moderators see every value read-only with the reason; the form submits the token of the version it drew (never an id) and a stale token, or a lost insert race (`RecordNotUnique` on `replaces_id`), is `Failure(:settings_changed)` shown as "Un autre administrateur vient de modifier les réglages." with typed values kept; the candidate is a whole row of the editable columns, validated as a whole, every violation reported at once; the new version copies `open`, both confirmation times and `first_opened_at` from the current one and records the author; one `SettingsChanged` published inside the transaction, heard by nobody; the announcement in both languages is required and a refused announcement rolls the whole change back; a GET never writes; no id in URLs, HTML or DOM; every string in `en.yml` and `fr.yml`, `errors.game.<code>` added by hand; no inline style; CSS under 500 lines per file.

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
| Blank or non-numeric | a required field empty or not a number | nothing written | violation `not_a_number` beside the field |
| Optional fields | alert thresholds and income targets blank | stored null | none |
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
- Ranges proposed for the author's approval (none is bounded by `market-economy.md`): commission 0 to 2500 basis points (0% to 25%, as spec); increment 100 to 2000 bp (1% to 20%); each of the three durations 1 to 720 hours, strictly ascending short < medium < long, the preselected one among the three (matches the table's check); soft close 30 to 900 seconds; average sale count 3 to 20 (never under the few-sales constant 3); average window 7 to 365 days; feed threshold multiple 2 to 100; unusual maximum multiple 2 to 20; alert destroyed share 0 to 10000 bp; alert picoins per player and alert top share (1 to 10000 bp) optional above zero; income-day targets optional, 0.001 to 365 days.
- Targets for the day of income get no starting value here (the first version stays untouched and the columns are nullable); epic 41's indicators say "not enough data" until an administrator sets them. The form shows them blank-able.
- Percent columns (commission, increment, alert shares) are typed in percent with up to two decimals and converted to basis points by the form object, rounding to the nearest basis point.
- The page's stale-save message is the dedicated line "Un autre administrateur vient de modifier les réglages." (`back_office.market_settings.stale` in both locales), not the generic `errors.game.settings_changed` text, which stays for operations reached elsewhere.
- Failed saves re-render the Marché page with 422 and the typed values, the current version's values shown next to a stale refusal so the administrator can redo the change; success redirects with a notice (303).
- Table layout: three rows (entrustment pays, stamp, minimum price) by five rarity columns, plus the income-target row; each input is named by its row and column headers through `aria-labelledby`, its bound and moment of application in a hint read through `aria-describedby`, and its refusal in an element with `role="alert"` beside it with `aria-invalid`.
- When each setting applies is stated as text per group: entrustment values and the cap at once; stamp and minimum at listing; durations, increment, soft close, unusual maximum at an auction's creation; commission at close; average count and window, feed threshold at once.
- The form draws from a `SettingsForm` value object built from a settings row, so epic 41 prefills it by building the object from another source; this story adds no prefill input.
- Moderators reach the page read-only (epic assumption); the opening section stays as story 2 left it, below the settings section.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/settings.rb` -- insert-only row; `successor(author:, **changes)` copies everything except id, token, author, replaces, created time and carries `open`, confirmations and first opening.
- `app/domains/game/app/operations/game/market/open_market.rb`, `announces_change.rb` -- the shape to follow: administrator check, one transaction, `RecordNotUnique` to `settings_changed`, `announce`, `publish(SettingsChanged..., stream_name: "Game::Market$settings")`, `Deadlocked` to `market_busy`.
- `app/domains/game/app/queries/game/market/current_settings.rb`, `entrust_cards.rb` -- current version read every time; entrusting already refuses a stale token with `amounts_changed`, so no change there.
- `app/domains/game/app/models/game/market/starting_settings.rb` -- the column names and the starting values.
- `db/migrate/20261110090000_create_game_market_tables.rb` -- columns, nullability and checks (commission 0 to 2500, preselected among the durations) that the rules must agree with.
- `app/controllers/back_office/{markets,market_openings}_controller.rb`, `app/policies/back_office/market{,_opening}_policy.rb` -- the Marché page, the `Opening` data object and the 422 re-render pattern to mirror.
- `app/views/back_office/markets/{show,_opening,_announcement}.html.erb` -- the announcement fieldset takes `opening:` and `disabled:`; reuse it with the draft's messages.
- `app/helpers/picoins_helper.rb`, `app/components/picoin_amount_component.rb` -- exact amounts in hints and refusals.
- `config/routes.rb` (back-office scope, `resource :market_opening`), `config/locales/{en,fr}.yml` (`back_office.markets.*`, `errors.game.*`), `app/frontend/styles/back-office-market.css`.
- `test/support/market.rb` (`open_market!`, `close_market!`), `test/domains/game/market/open_market_test.rb`, `test/system/back_office_market_test.rb`, `test/system/market_entrust_test.rb`, fixtures `accounts_players(:administrator|:moderator|:player)`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/settings_rules.rb` -- new pure object: `EDITABLE` columns, `SettingsRules.new(current).violations(candidate)` returning `{ field => Violation(code, values) }` for the ratio bound, no-loss floor, ranges, ascending durations, preselected among durations, optional fields; `floor(entrustment, stamp, commission_bp)` public -- one place for every bound, read by the operation and the form
- [ ] `app/domains/game/app/operations/game/market/change_settings.rb` -- `call(player:, settings_token:, candidate:, message_fr:, message_en:)`: administrator check, then in one transaction read current, refuse a token mismatch or no version with `settings_changed`, `invalid_settings` on any violation, insert `current.successor(author: player, **candidate.slice(*EDITABLE))`, rescue `RecordNotUnique` as `settings_changed`, `announce`, publish `SettingsChanged`, rescue `Deadlocked` as `market_busy`; returns the new row -- the change itself
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.invalid_settings` plus the dedicated page strings (below) in both files, by hand
- [ ] `app/models/back_office/market_settings_form.rb` -- value object from a settings row or submitted params: typed values per field, percent to basis points and back, `candidate` hash, per-field violation lookup, `token` -- what the page draws and the controller submits
- [ ] `config/routes.rb` -- `resource :market_settings, path: "market/settings", only: :create` in the back-office scope
- [ ] `app/policies/back_office/market_setting_policy.rb` -- `create?` for administrators (the page itself stays under `MarketPolicy#show?`)
- [ ] `app/controllers/back_office/market_settings_controller.rb` -- create: authorize, rate limit 10 a minute, call `ChangeSettings` with `params[:settings_token]`, the form's candidate and both messages; success redirects 303 with a notice; failure re-renders `back_office/markets/show` with 422, the typed form, the per-field violations from `SettingsRules` and, for `settings_changed`, the stale line
- [ ] `app/controllers/back_office/markets_controller.rb` -- show also builds `@settings_form` from the current version (read only)
- [ ] `app/views/back_office/markets/show.html.erb`, `_settings.html.erb`, `_settings_rarities.html.erb`, `_settings_field.html.erb` -- settings section above the opening: rarity table (row and column headers naming each input), grouped single fields each with bound and moment hints, the announcement fieldset with both languages required, refusals beside fields with `role="alert"` and `aria-invalid`, the stale refusal at the top; for a moderator every control disabled with the reason
- [ ] `app/frontend/styles/back-office-market-settings.css`, `app/frontend/entrypoints/application.css` -- table and field layout on existing tokens, narrow-screen scrolling confined to the table; no inline style
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `back_office.markets.settings.*` (headings, row and column labels, hints with bounds and moments, violations `more_than_double`, `less_than_half`, `below_floor`, `out_of_range`, `not_a_number`, `durations_not_ascending`, `preselected_not_a_duration`), `back_office.market_settings.{saved,stale}`; French stale line "Un autre administrateur vient de modifier les réglages."
- [ ] Tests: `test/domains/game/market/{settings_rules,change_settings}_test.rb` (each bound at its edges, the floor and the stamp-raised case, open and first opening copied across versions, author recorded, the concurrent save by a version inserted between draw and save, bad announcement rolling back, moderator and player refused, deadlock), `test/policies/back_office/market_setting_policy_test.rb`, `test/models/back_office/market_settings_form_test.rb`, `test/controllers/back_office/market_settings_controller_test.rb` (success, per-field refusal with 422 and typed values, stale line, moderator POST refused, page read-only for a moderator), `test/system/back_office_market_test.rb` -- one system test: an administrator raises the Rare stamp and minimum with both announcements, a player sees the announcement, and a Confier form drawn before the save is refused with the new amounts

**Acceptance Criteria:**
- Given an administrator on the Marché page, when the Rare stamp and the Rare minimum are raised within bounds and both announcements typed, then a new version is current, the announcement replaces the one shown, and a Confier form drawn before is refused with the new amounts drawn and the ticks kept.
- Given a minimum below its no-loss floor, when saved, then nothing changes and the refusal beside that field names the floor.
- Given two administrators who opened the page on the same version, when the second saves after the first, then the second sees "Un autre administrateur vient de modifier les réglages." with its typed values kept.
- Given the market is open or closed, when a change is saved, then the new version keeps that state and the first opening time.
- Given a moderator, when the page is opened, then every value is readable, every control disabled and the reason shown.
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
