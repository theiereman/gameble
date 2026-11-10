---
title: 'An administrator opens the market from the back-office'
type: 'feature'
ticket: '2'
created: '2026-11-10'
status: 'draft'
baseline_revision: '5ef2bb5aeadbcc785f3862f3f39493d3becb3773'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/epic-picoins-and-entrusting.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/market-economy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The market exists only as a closed settings version; nothing lets an administrator open it, record the legal confirmations or announce it, so no player can entrust outside tests.

**Approach:** `Game::Market::OpenMarket` inserts a new open settings version (confirmations and first opening recorded) and announces it through `Accounts::CreateAnnouncement` in the same transaction; `Game::Market::MarketState` answers open and first opened; a staff-gated back-office Marché page carries the opening form; the development seed opens the market. Epic requirements R19 (announcement step), R21 (opening and reopening), R22 (state only).

## Boundaries & Constraints

**Always:** administrators only for the operation and the POST; moderators see the page with every control disabled and the reason; the new version copies every value of the current one and names it in `replaces_id` (a lost race is `Failure(:settings_changed)`); both confirmations are required every time, a reopening included, and the first opening time is kept once set; the announcement is typed in French and English, validated by `Accounts::CreateAnnouncement`, shown true, and rolls the whole opening back if refused; one `SettingsChanged` published per opening, inside the transaction, heard by nobody; a GET never writes; no database id in URLs or HTML; every string in `en.yml` and `fr.yml`, `errors.game.<code>` added by hand; the teaser stays at the market's address.

**Never:** closing the market and the settings form (stories 9 and 10 own them; this page shows no close button), the switch from teaser to market (epic 39), the Balance chip (story 8), a cached settings read, a second writer of settings rows.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| First opening | closed, never opened; admin, both confirmations, both messages | new open version, both confirmation times and `first_opened_at` set, announcement shown replacing the previous, `SettingsChanged` | none |
| Reopening | closed, `first_opened_at` set | new open version, confirmations re-recorded, `first_opened_at` unchanged | none |
| Already open | current version open | nothing written | `market_already_open` |
| Missing confirmation | terms or odds not true | nothing written | `terms_not_confirmed` / `odds_not_confirmed` |
| Bad announcement | a language empty or over length | nothing written, version rolled back | `invalid_announcement` |
| Not an administrator | moderator, player, banned | nothing written | `administrator_required` |
| Lost race | another version inserted first | nothing written | `settings_changed` |
| Deadlock | `ActiveRecord::Deadlocked` | rolled back | `market_busy` |
| Moderator on the page | GET | form shown, all controls disabled, reason text | POST refused by policy |
| Non-staff | GET or POST | address answers as unknown (404) | none |

## Decisions

- The two confirmations have separate failure codes (`terms_not_confirmed`, `odds_not_confirmed`) so the form names the missing one.
- A reopening asks both confirmations again and keeps `first_opened_at` (epic note); the same form serves it, labelled "Rouvrir le marché".
- The page shows no close button until story 10; while the market is open it shows its state only.
- The announcement step is a shared concern (`announce`) and the copy step a `Settings#successor` builder, reused by stories 9 and 10.
- Moderators reach the page read-only (epic assumption); only administrators post.
- The development administrator is fake player 0 ("Dev Player"), promoted by the seed since none exists in development.
- A failed opening re-renders the page with 422 and the typed values rather than redirecting, so nothing typed is lost.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/models/game/market/settings.rb` -- insert-only version (`readonly?` once persisted); add the successor builder.
- `app/domains/game/app/operations/game/market/create_first_settings.rb` -- publishes `SettingsChanged` with `settings_id` on stream `Game::Market$settings`; follow it.
- `app/domains/game/app/queries/game/market/current_settings.rb` -- highest id, read each time.
- `app/domains/game/app/operations/game/operation.rb` -- `Game::Operation` (`player:` required, `require_player`); `entrust_cards.rb` for the `rescue ActiveRecord::Deadlocked` shape.
- `app/domains/accounts/app/operations/accounts/create_announcement.rb`, `announcement_writing.rb` -- `call(staff:, message_fr:, message_en:, shown:)`, fails `:invalid_announcement`; its inner transaction joins ours when called through `step`.
- `app/domains/accounts/app/models/accounts/player.rb` -- `acting_staff?`, `administrator?`, `Announcement::MESSAGE_LENGTH`.
- `app/controllers/back_office/{base,announcements,roadmaps}_controller.rb` -- staff gate, rate limit, 422 re-render pattern; `app/policies/back_office/roadmap_policy.rb` and its test for policy shape.
- `app/views/back_office/announcements/{index,_fields}.html.erb` -- the two language fields to reuse; `app/helpers/back_office_dashboard_helper.rb`, `back_office_tile_component.*`, `script/pixel_art/back_office_icons.mjs` -- dashboard tiles and their icons.
- `config/routes.rb:215-285` -- back-office scope; `app/controllers/markets_controller.rb`, `app/views/markets/show.html.erb` -- the teaser, left untouched.
- `db/seeds.rb` -- idempotent blocks; `app/controllers/dev_sign_ins_controller.rb` (`steam_id(0)`, "Dev Player"); `Accounts::SetRole`.
- `test/support/market.rb` (`open_market!`, `close_market!`), `test/system/market_entrust_test.rb`, `test/controllers/back_office/announcements_controller_test.rb`, fixtures `accounts_players(:administrator|:moderator|:player)`.
- `app/frontend/styles/announcement.css`, `back-office-dashboard.css`, `entrypoints/application.css` -- styles and their import.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/models/game/market/settings.rb` -- add `successor(author:, **changes)`: unsaved row copying every column except id, token, author, replaces, created_at, with `replaces_id` set to self -- the one way later stories build a new version
- [ ] `app/domains/game/app/models/game/market/market_state.rb` -- `MarketState.call(settings = CurrentSettings.call)` returns a `Data` with `open?`, `first_opened?`, `first_opened_at`; no settings means closed, never opened -- read by story 8, 10 and epic 39
- [ ] `app/domains/game/app/operations/game/market/announces_change.rb` -- concern with private `announce(player, message_fr, message_en)` stepping `Accounts::CreateAnnouncement.new.call(staff: player, ..., shown: true)` -- shared by openings and every settings change
- [ ] `app/domains/game/app/operations/game/market/open_market.rb` -- `call(player:, terms_confirmed:, odds_confirmed:, message_fr:, message_en:)`: administrator check, confirmations (terms first), then in one transaction read current settings, refuse if open, insert the successor with `open: true`, both confirmation times and kept-or-new `first_opened_at`, rescue `RecordNotUnique` as `settings_changed`, announce, publish `SettingsChanged`; rescue `Deadlocked` as `market_busy`; return the new settings
- [ ] `config/routes.rb` -- under the back-office scope `resource :market, only: :show` and `resource :market_opening, path: "market/opening", only: :create`
- [ ] `app/policies/back_office/market_policy.rb`, `market_opening_policy.rb` -- `show?` for staff; `create?` for administrators
- [ ] `app/controllers/back_office/markets_controller.rb`, `market_openings_controller.rb` -- show loads `MarketState` and current settings; create authorizes, rate limits 10 a minute, calls `OpenMarket` with the checkbox values (`"1"`), redirects with a notice on success, re-renders show with 422 and the typed values on failure
- [ ] `app/views/back_office/markets/show.html.erb`, `_opening.html.erb`, `_announcement.html.erb` -- state line (never opened, open since, suspended), opening section with the two checkboxes, the announcement fieldset reused by later settings forms, button "Ouvrir le marché" or "Rouvrir le marché" after a first opening; hidden while open; for a moderator every control disabled with the reason described by `aria-describedby`
- [ ] `app/views/back_office/announcements/_fields.html.erb` -- optional `disabled:` local passed to both textareas
- [ ] `app/helpers/back_office_dashboard_helper.rb`, `script/pixel_art/back_office_icons.mjs` -- a `market` tile in a new `market` group (`action: :show?`), its 11 x 11 icon, then `node script/pixel_art/export.mjs` for the generated SVG
- [ ] `app/frontend/styles/back-office-market.css`, `entrypoints/application.css` -- layout of the opening section using existing tokens, no inline style
- [ ] `config/locales/en.yml`, `fr.yml` -- `back_office.market.*`, `back_office.dashboard.show.tiles.market`, `groups.market`, and `errors.game.{administrator_required,terms_not_confirmed,odds_not_confirmed,market_already_open,settings_changed,invalid_announcement}` (`market_busy` exists)
- [ ] `db/seeds.rb` -- development only, after the fake players: sign in fake player 0, `Accounts::SetRole` to administrator, and while `MarketState` is not first opened call `OpenMarket` with both confirmations and a short announcement in both languages
- [ ] Tests: `test/domains/game/market/{open_market,market_state}_test.rb`, `test/policies/back_office/{market,market_opening}_policy_test.rb`, `test/controllers/back_office/{markets,market_openings}_controller_test.rb` (including the teaser still answering at `market_path` after opening and the dashboard tile), `test/system/back_office_market_test.rb`

**Acceptance Criteria:**
- Given a closed market and an administrator on the Marché page, when both confirmations are ticked, both announcements typed and "Ouvrir le marché" pressed, then the market is open, a player sees the announcement banner and entrusts copies on the Confier page.
- Given the same page, when one confirmation is missing, then nothing opens and the refusal names it.
- Given a moderator, when the page is opened, then the section is readable with every control disabled and the reason shown.
- Given an announcement already shown, when the market opens, then only the new one is shown.
- Given an open market, when the market address is visited, then the teaser still answers.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

`successor` and `announce` exist so story 9's `ChangeSettings` and story 10's closing add no copying or announcement code of their own; only the changed values differ. `MarketState` reads `first_opened_at` from the current row because every version carries it forward.


## Verification

**Commands:**
- `bin/rails test test/domains/game/market test/policies/back_office test/controllers/back_office test/controllers/markets_controller_test.rb` -- pass
- `bin/rails test test/system/back_office_market_test.rb` -- pass
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `npm run format:check`, `npm run lint:css`, `node script/pixel_art/export.mjs --check`, `bundle exec i18n-tasks health` -- clean

**Manual checks (if no CLI):**
- In development, `bin/rails db:seed` opens the market; signing in as Dev Player shows the banner and the Confier page entrusts; a second seed run changes nothing.
