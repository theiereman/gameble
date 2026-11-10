---
title: 'An administrator closes and reopens the market, and a closed market refuses entrusting'
type: 'feature'
ticket: '38.10'
created: '2026-11-10'
status: 'draft'
baseline_revision: '059e0eb1f3747ac554983bff74235ec8933650e8'
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
  - '{project-root}/_bmad-output/initiative-gameble/epic-picoins-and-entrusting/story-an-administrator-changes-the-economy-settings-with-the-broth-plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** An administrator can open the market but not close it, and once it is closed after a first opening the Confier page only shows a plain notice instead of the Brotherhood's suspended banner that every market screen is to share.

**Approach:** `ChangeSettings` gains a closing path (a new version with `open` false, announced and published like any change); a back-office closing section shows "Fermer le marché" while the market is open, the existing opening section serving "Rouvrir le marché" after; a shared suspended banner partial built on the `market_closed` wording replaces the plain notice on Confier once the market has been opened before, disables validation with the banner as its reason and leads back to the market. Epic requirements R19 (closing announcement), R21 (closing and reopening), R22 (closed state on Confier).

## Boundaries & Constraints

**Always:** administrators only for the closing operation and its POST; moderators see the section with its control disabled and the reason; closing copies every value, both confirmation times and `first_opened_at` from the current version, sets `open` false and records the author; closing needs the announcement in both languages, published in the same transaction through `AnnouncesChange`, a refused announcement rolls the closing back; one `SettingsChanged` published inside the transaction, heard by nobody; the closing form submits the token of the version it drew (never an id) and a stale token, no version, or a lost insert race is `Failure(:settings_changed)`; reopening is the existing `OpenMarket` with its two confirmations again and its announcement, and keeps the first opening time; `EntrustCards` already answers `market_closed` for a closed or absent version and stays untouched; a GET never writes; no database id in URLs or HTML; every string in `en.yml` and `fr.yml`, `errors.game.<code>` by hand; no `style` attribute; the suspended banner is a server-rendered partial with no script; the teaser stays at the market's address whatever the state; the card detail keeps hiding CONFIER through its existing state check.

**Never:** a second writer of settings rows, an `open` key accepted from a settings form (the settings form still cannot set it), opening through `ChangeSettings`, the suspended banner on the market screen or the Annonce (epic 39 story 11 reuses the partial there), disabling other market actions (they do not exist yet), a confirmation dialog before closing (the required announcement is the deliberate step), a migration, an edit of the stories 2 and 9 plans.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Close | open version; administrator, current token, both messages | new version `open` false, author set, `first_opened_at` and confirmation times carried, announcement shown replacing the previous, `SettingsChanged` | none |
| Reopen after closing | closed version with `first_opened_at`; `OpenMarket` with both confirmations | new open version, confirmations re-recorded, `first_opened_at` unchanged | none |
| Already closed | current version closed | nothing written | `market_already_closed` |
| No version | no settings row | nothing written | `settings_changed` |
| Stale or blank token | token of an older version, or none | nothing written | `settings_changed` |
| Bad announcement | a language empty or over length | nothing written, version rolled back | `invalid_announcement` |
| Not an administrator | moderator, player, banned | nothing written | `administrator_required` |
| Deadlock | `ActiveRecord::Deadlocked` | rolled back | `market_busy` |
| Moderator on the page | GET while open | closing section shown, control disabled, reason text | POST refused by policy |
| Confier, suspended | version closed, `first_opened_at` set, player | banner (title, body, link to the market) in place of the plain notice, validation disabled and described by the banner, page otherwise readable | none |
| Confier, never opened | version closed, no `first_opened_at` | the plain closed notice as before, validation disabled | none |
| POST entrust while closed | any token, any batch | nothing minted, page redrawn with 422, ticks kept, the `market_closed` line | `market_closed` |
| Market address while closed | GET `market_path` | the teaser | none |

## Decisions

- Closing is `ChangeSettings#call(player:, settings_token:, candidate: {}, message_fr:, message_en:, close: false)`: with `close: true` the candidate is ignored, the rules are skipped (nothing but `open` changes) and the successor is built with `open: false`; a current version already closed fails `market_already_closed`. This keeps R21's "`ChangeSettings` can close the market" and the single settings writer, and `open` is still not an editable column.
- A new failure code `market_already_closed` mirrors `market_already_open`, with `errors.game.market_already_closed` in both locales.
- The closing form is its own route and controller (`market_closing`, create only), mirroring the opening: separate policy, rate limit 10 a minute, 422 re-render with the typed announcement, 303 redirect with a notice on success. It is not folded into the settings form, so saving values never closes the market.
- The page shows the closing section only while the market is open and the opening section only while it is closed (one `if` / `else` in `show.html.erb`); the settings section stays above both and renders in both states.
- The closing section reuses the announcement partial with dom `market-closing-announcement`, scope `market_closing`, reason id `market-closing-reason`, so no id or field name clashes; its token travels as `market_closing[token]`, taken from the settings form's version.
- Failure lines on the closing form are dedicated: `settings_changed` says another administrator changed the market meanwhile and the page was redrawn, `invalid_announcement` says each announcement needs text in both languages and the market was not closed (the generic key says "not opened" and is left alone), others use the operation's `failure_message`.
- The suspended banner is `app/views/market/_suspended_banner.html.erb`, no locals except the optional heading level, with the stable id `market-suspended-banner`, a `role="status"` region, the title "LE MARCHÉ EST SUSPENDU" and the Copy deck body, and a link variant `ButtonComponent` "Retour au marché" to `market_path`. It lives under `market/` so the market screen and the Annonce render it by name. English wording (the Copy deck has no English): title "THE MARKET IS SUSPENDED", body "The Brotherhood is auditing its procedures. Auctions in progress end normally. Nothing can be entrusted, sold or bid on for now."
- Confier shows the banner only when the market was opened before and is closed now (`MarketState#first_opened?` and not `open?`); before the first opening the existing plain notice stays, since R22 allows no market action there and the Copy deck's banner is defined for "after a first opening".
- Validation stays disabled by the existing `open` value; the banner is its reason: the submit button's `aria-describedby` carries the banner id. The recap controller overwrites that attribute on every render, so it gains a string value `reason-id` and appends it when set.
- The banner's wording is built on `errors.game.market_closed` by sharing its meaning, not its text: the refusal line stays "The market is closed for now. Nothing was entrusted." for a POST sent while closed.
- Banner style: 2px `--color-alert` frame on a tenth of that colour (`color-mix`, precedent in `landing-hero.css`), title in `--color-alert`, in its own `market-suspended.css`.
- `test/support/market.rb` is not changed; suspended-state tests build the version with `close_market!(first_opened_at: Time.current)`.

</frozen-after-approval>

## Code Map

- `app/domains/game/app/operations/game/market/change_settings.rb` -- settings writer; add the closing path beside the candidate path (shared `require_administrator`, `current_version`, `announce`, `publish`, rescues).
- `app/domains/game/app/operations/game/market/open_market.rb`, `announces_change.rb` -- reopening as it stands; `opened_version` keeps `first_opened_at`.
- `app/domains/game/app/models/game/market/settings.rb`, `market_state.rb` -- `successor(author:, open: false)` carries everything else; `MarketState#first_opened?` drives the banner.
- `app/controllers/back_office/{markets,market_openings,market_settings}_controller.rb`, `app/controllers/concerns/back_office/market_page.rb` -- the page, the `Opening` data object, `render_market_page` and the 422 re-render pattern to mirror.
- `app/views/back_office/markets/{show,_opening,_announcement,_settings}.html.erb` -- the opening form, the announcement partial's `dom`/`scope`/`legend`/`reason_id` locals.
- `app/policies/back_office/market_opening_policy.rb` and its test -- policy shape.
- `config/routes.rb:271-276` -- back-office market routes.
- `app/controllers/market/entrustments_controller.rb` (`load_page`, `create` refusal path), `app/views/market/entrustments/{new,_recap}.html.erb` -- the plain `.closed` notice, `@open`, the submit button's `describedby`.
- `app/frontend/controllers/entrust_recap_controller.ts` (`reflectSubmit`) and its test -- rewrites `aria-describedby` on each render.
- `app/views/cards/` card detail and `Game::Market::CardEntrustment` -- already absent when closed; only covered by a test here.
- `app/views/markets/show.html.erb`, `app/controllers/markets_controller.rb` -- the teaser, untouched.
- `app/frontend/styles/{market-entrust,back-office-market,market-teaser}.css`, `entrypoints/application.css` -- styles and imports.
- `config/locales/{en,fr}.yml` -- `back_office.markets.{opening,announcement}`, `market.entrustments.new.{closed,closed_action}`, `errors.game.{market_closed,market_already_open}`.
- `test/support/market.rb`, `test/domains/game/market/{change_settings,open_market}_test.rb`, `test/controllers/{back_office/market*,market/entrustments}_controller_test.rb`, `test/system/{back_office_market,market_entrust}_test.rb` -- patterns and helpers.

## Tasks & Acceptance

**Execution:**
- [ ] `app/domains/game/app/operations/game/market/change_settings.rb` -- add `close: false` and default `candidate: {}`; when closing, skip the rules, fail `market_already_closed` on a closed current version, and insert `current.successor(author: player, open: false)`; announce and publish as today -- the closing, one writer
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `errors.game.market_already_closed` by hand
- [ ] `config/routes.rb` -- `resource :market_closing, path: "market/closing", only: :create` in the back-office scope
- [ ] `app/policies/back_office/market_closing_policy.rb` -- `create?` for administrators
- [ ] `app/controllers/back_office/markets_controller.rb`, `app/controllers/concerns/back_office/market_page.rb` -- a `Closing` data object (`message_fr`, `message_en`, `refusal`), `@closing ||= Closing.new` in the page and in `render_market_page`
- [ ] `app/controllers/back_office/market_closings_controller.rb` -- create: authorize, rate limit 10 a minute, read `params[:market_closing]` through an allow-list (`token`, `message_fr`, `message_en`), call `ChangeSettings` with `close: true`; success redirects 303 with a notice; failure re-renders the Marché page with 422, the typed announcement kept and the dedicated refusal line
- [ ] `app/views/back_office/markets/_closing.html.erb`, `show.html.erb` -- closing section `id="market-closing"` with its heading, the announcement partial (dom `market-closing-announcement`, scope `market_closing`, reason `market-closing-reason`), a hidden `market_closing[token]`, the refusal in a `role="alert"` list and a "Close the market" button, disabled with the reason for moderators; `show` renders it only while open and the opening section only while closed
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `back_office.markets.closing.{heading,administrators_only,close}` ("Fermer le marché"), `back_office.market_closings.{create.closed,stale,announcement_refused}`
- [ ] `app/views/market/_suspended_banner.html.erb`, `app/frontend/styles/market-suspended.css`, `app/frontend/entrypoints/application.css` -- the shared banner and its style, imported after the market styles
- [ ] `config/locales/en.yml`, `config/locales/fr.yml` -- `market.suspended_banner.{title,body,back}` ("LE MARCHÉ EST SUSPENDU", the Copy deck body, "Retour au marché")
- [ ] `app/controllers/market/entrustments_controller.rb`, `app/views/market/entrustments/new.html.erb`, `_recap.html.erb` -- `@suspended` from `MarketState.call(@settings)`; render the banner instead of the plain notice when suspended, keep the plain notice when never opened; the submit button describes itself by the banner id when suspended; pass `entrust_recap_reason_id_value`
- [ ] `app/frontend/controllers/entrust_recap_controller.ts` -- a `reasonId` string value; `reflectSubmit` appends it to `aria-describedby` when set and the element exists
- [ ] Tests: `test/domains/game/market/change_settings_test.rb` (closing: new version closed, first opening and confirmation times carried, author, announcement replaced, event published, already closed, no version, stale and blank token, bad announcement rolling back, moderator and player refused, deadlock), `test/domains/game/market/open_market_test.rb` (close then reopen keeps `first_opened_at` and re-records confirmations), `test/policies/back_office/market_closing_policy_test.rb`, `test/controllers/back_office/market_closings_controller_test.rb` (success, refusals each 422 with typed text, non-staff 404), `test/controllers/back_office/markets_controller_test.rb` (closing section only while open, opening only while closed, moderator disabled), `test/controllers/market/entrustments_controller_test.rb` (banner and link when suspended, plain notice when never opened, submit described by the banner, a POST while closed refused with `market_closed`, 422, nothing minted), `test/controllers/markets_controller_test.rb` (teaser while closed after an opening), `app/frontend/controllers/entrust_recap_controller.test.ts` (describedby keeps the reason id), `test/system/market_suspension_test.rb`

**Acceptance Criteria:**
- Given an open market and an administrator on the Marché page, when both announcements are typed and "Fermer le marché" pressed, then the market is closed, the announcement replaces the one shown, and the page offers "Rouvrir le marché" in place of the closing section.
- Given a suspended market, when a player opens Confier, then the suspended banner shows with its link back to the market, validation is disabled and described by the banner, and the card detail has no CONFIER.
- Given a suspended market, when the administrator reopens it with both confirmations, then the player entrusts a batch as before and `first_opened_at` is the original time.
- Given a closed market, when an entrust POST is sent, then nothing is minted and the player sees the `market_closed` refusal with the ticks kept.
- Given a closing with a missing announcement, a stale page or a moderator, then nothing is written and the refusal is shown (or the control is disabled with its reason).
- Given a market closed after an opening, when the market address is visited, then the teaser answers.
- Given a market never opened, when Confier is visited, then the plain closed notice shows, not the banner.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

Closing has no candidate: `current.successor(author:, open: false)` carries every value, so only `open` differs and the settings bounds do not apply. The single `if @state.open?` in `show.html.erb` keeps the opening and closing sections from ever sharing a page, though their announcement partials already use distinct ids.

```erb
<%= render "market/suspended_banner" if @suspended %>
```

## Verification

**Commands:**
- `bin/rails test test/domains/game/market test/policies/back_office test/controllers/back_office test/controllers/market test/controllers/markets_controller_test.rb` -- pass
- `bin/rails test test/system/market_suspension_test.rb` -- pass
- `npm run test:js`, `npm run format:check`, `npm run lint:css` -- clean
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `script/check_file_sizes`, `script/check_planning_references`, `bundle exec i18n-tasks health` -- clean

**Manual checks (if no CLI):**
- In development, close the market from the back-office, then open Confier as Dev Player: the banner shows, validation is disabled; reopen it and entrust.
