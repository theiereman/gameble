---
title: 'A Me page that is your profile, edited live'
type: 'feature'
ticket: '12'
created: '2026-11-03'
status: 'built'
baseline_revision: '7339ea8efe1beb012b274b658d0e012f5f53abb6'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: [oversized]
deferred:
  - summary: >-
      A screen restored from the Turbo cache by Back shows stale stream badges; Me now joins it with its achievements badge.
    evidence: |-
      own_profiles/show.html.erb is cached (the back picker's restore-by-Back flow depends on it) and holds #plus-achievements-badge; achievement claims and player streams update that id only in the live DOM. The tab bar's #tab-me-badge has the same staleness on every cached screen. Settle by refreshing badges on turbo:load of a restoration visit, or by exempting Me and dropping the restore test.
    location: >-
      app/views/public_profiles/_achievements.html.erb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The Me tab opens an interim menu (Settings, Personalization, Achievements, How it works, Support); the player's public profile and the separate Personalization page (showcase, card back, title) are two screens, so a change is made on one and seen on the other.

**Approach:** `/me` renders the player's own public profile (the same partials visitors see at `/brothers/:token`) with the title, the card back and the showcase each opened by touching them into the shared bottom sheet, the result shown at once; the achievements section previews progress and links to the full list; at the bottom, How it works and one Settings link. `/personalization` redirects for good to `/me`.

## Boundaries & Constraints

**Always:** server-rendered ERB, no markup built in script (clone server-rendered `<template>`s); `BottomSheetComponent` and `bottom_sheet_opener` for every sheet; en and fr strings together (fr plural keys with `zero`); every action behind a Pundit policy; GET never writes; no ids in HTML (tokens, slugs, back keys only); no `style` attribute; tap targets at least 44px; file limits (400 Ruby/TS, 500 CSS); the card back stays private (only the owner sees it, as its existing "Only you see it" line says); the settings page keeps language, visibility, motion, Steam library, session, sign-ins, data, deletion, support and legal unchanged.

**Decisions (conservative readings):** the Me page lives at `/me`, not at `/brothers/:token`; the owner's `/brothers/:token` page stays as it is. Moving showcase cards stays in place on the profile (drag and the existing ◀ ▶ buttons, as the owner's profile has them today); the showcase sheet removes cards and says how to add one. The name stays editable in the settings. The desktop player menu keeps Settings, back office and sign out, and its Personalization and "My public profile" entries become one "My profile" link to `/me`. Support leaves the Me page (the settings page holds it).

**Never:** a new operation, migration or change to the game domain; the name, visibility or account items moved out of the settings; pixel icons (no new icon is needed: openers carry text); the bell, Social or Sets screens; building on or merging the draft branch `profile-settings-rework`; adding tests to `test/system/shell_test.rb` or `test/integration/shell_test.rb` beyond fixing broken assertions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Me | signed-in player, GET /en/me | own profile: name h1, title, showcase, stats, achievements, sets; owner-only title opener, card back preview opener, showcase Edit opener; How it works then Settings at the bottom; Me tab current; full (top-level) phone header | none |
| Visitor of Me | signed out, GET /en/me | redirected to the landing in its locale, no alert (as today) | none |
| Card back | tap the back preview, tap an unlocked back in the sheet | back equipped in JSON, announced, and the band's preview shows the new back and its name with no page load | failure: the picker's failure line, preview unchanged |
| Card back without JS | submit a back form | redirect to /me with the back sheet sent open, focus on the chosen back | locked back: alert toast (existing refusal) |
| Title | tap the title, tap "Adept · Valve" in the sheet | page re-renders on /me with the title in the band and the TITLE EQUIPPED toast; "No title" removes it with its toast | forged title: refusal toast, nothing written |
| Showcase removal | tap Edit on the showcase, tap ✕ of a card | redirect to /me, card gone from the profile, removal toast, sheet sent open with focus on the next card's ✕ (or the sheet's first choice when none is left) | card not in showcase: existing refusal |
| Empty showcase | owner with no chosen card | Me shows the showcase section with its empty line and the Edit opener; visitors see no showcase section | none |
| Visitor sees the same | another player opens the owner's /brothers/:token | same name, title and showcase order as on the owner's Me, with no opener, no card back and no sheet | none |
| Old page | GET /fr/personalization | 301 to /fr/me | none |
| Card detail from Me | tap a showcase card on Me | detail's back button leads to /me, labelled Me | none |

</intent-contract>

## Code Map

- `config/routes.rb:110-116,167-171` -- `resource :personalization, only: :show` (replace with `get "personalization", to: redirect("/%{locale}/me", status: 301)` like the `more` redirect); keep `personalization_title` / `personalization_back` PATCH routes; `get "me" => "pages#me"` becomes `own_profiles#show`.
- `app/controllers/pages_controller.rb:28-30` `me` action and `app/views/pages/me.html.erb` -- remove; `pages.me.*` locale keys go with them.
- `app/controllers/public_profiles_controller.rb` -- `show`, `capped_at_card_total`, `load_relation`, `load_season_sections`, `started_standings`, `most_complete_set_tiles`: extract into a `ProfileLoading` concern (`load_profile(owner)`) shared with the new controller; uses `SetBoardLoading#set_rows/set_tiles` and `ChosenCards#chosen_cards`. Keep its queries unchanged.
- `app/controllers/personalizations_controller.rb`, `app/policies/personalization_policy.rb`, `app/views/personalizations/show.html.erb`, `_section.html.erb`, `_showcase.html.erb`, `_title_picker.html.erb` -- remove. Keep `_back_picker` (drop its `personalizations/section` panel wrapper; the sheet gives the frame), `_back_group`, `_back_tile`, `_back_detail`, `_back_chip`, `_section_head` only if still used. `personalizations.show.card_back.*` keys stay (used by `CardBacksHelper`).
- `app/controllers/card_backs_controller.rb:20`, `profile_titles_controller.rb:11`, `concerns/personalization_refusal.rb:8` -- redirect to `me_path` instead of `personalization_path`.
- `app/controllers/cards_controller.rb:19,134-139` `personalization_browse` (`from=personalization`, label `shell.player.personalization`) -- becomes `from=me`, back labelled `t("shell.tabs.me")` to `me_path`.
- `app/views/public_profiles/_profile.html.erb`, `_summary.html.erb`, `_showcase.html.erb`, `_achievements.html.erb`, `show.html.erb` -- shared by both pages. `_showcase` derives card-link context from `owner`/`removable`/`framed`: replace with a `context:` local (`{ brother: owner.token }` on the brother page, `{ from: "me" }` on Me), drop `framed` and the removable/removed branches if nothing else uses them; keep the `movable` drag and ◀ ▶ (`showcase-order` controller) and `flash[:moved_showcase_card]` focus. `_profile` currently hides the showcase when empty; Me shows an empty section.
- `app/helpers/shell_helper.rb:59,66,70-77` -- `SCREEN_LABELS` `"pages#me" => :me` becomes `"own_profiles" => :me`; top-level list swaps `pages#me` for `own_profiles#show`; `ME_TAB_CONTROLLERS` drops `personalizations`, adds `own_profiles`.
- `app/views/shell/_player_chip.html.erb:8-11` -- menu entries (Settings, Personalization, My public profile).
- `app/components/bottom_sheet_component.rb/.html.erb`, `app/helpers/bottom_sheet_helper.rb` -- the sheet (`id:`, `title:`), opened by a link with `bottom_sheet_opener(id)`. The controller already upgrades a server-rendered `<dialog open>` to a modal (`showSentOpenAsModal`): add an `open: false` keyword that renders the dialog `open`, with a component test.
- `app/frontend/controllers/back_picker_controller.ts` `choose` -- after `equip`, `this.dispatch("equipped", { detail: { back, season } })`; nothing else changes. `lib/back_picker.ts` untouched.
- `app/views/library/_quick_filters.html.erb` -- reference for sheet content and `filter-chip` choices with `aria-current="true"` (`collection-filters.css` styles them).
- `app/views/pages/_menu_achievements_badge.html.erb`, `player_streams/_update.turbo_stream.erb:13`, `achievement_claims/create.turbo_stream.erb:6` -- update the slot `#plus-achievements-badge`; keep that id on Me's achievements link.
- `app/frontend/styles/personalization.css` (page and section rules; `.title-picker__select`), `back-picker.css` (strip `position: sticky; top: 0` on phone works inside the sheet body's scroll), `profile.css` (445 lines, near the limit), `settings.css:191-215` (`.plus`, `.menu-item--plus`), `entrypoints/application.css:25-31` imports.
- `app/helpers/profile_titles_helper.rb` `profile_title_options` -- unused once the select goes; remove with any test of it.
- Tests that reference the old screens: `test/controllers/personalizations_controller_test.rb`, `card_backs_controller_test.rb`, `profile_titles_controller_test.rb`, `card_back_seasons_controller_test.rb`, `showcases_controller_test.rb:142-212`, `settings_controller_test.rb:515-535`, `achievements_controller_test.rb:304`, `achievement_claims_controller_test.rb:34`, `test/integration/phone_tabs_test.rb`, `test/system/personalization_test.rb` (its five flows move to Me). `pages_controller_test.rb:422` (visitor redirect) and `card_preview_tags_test.rb:401` must still pass unchanged.

## Tasks & Acceptance

**Execution:**
- [ ] `app/controllers/concerns/profile_loading.rb`, `public_profiles_controller.rb` -- extract the profile loading; brother page behaviour and query count unchanged.
- [ ] `app/controllers/own_profiles_controller.rb`, `app/policies/own_profile_policy.rb` (`show? = player?`), `config/routes.rb` -- `show` authorizes, loads the profile of `current_player`, `@card_backs = Game::CardBackShelf.call`, `@titles = Game::ProfileTitles.call`, active title from those titles; personalization redirect route; remove the personalization controller, policy and `pages#me`.
- [ ] `app/views/own_profiles/show.html.erb` and partials (`_title_sheet`, `_back_sheet`, `_showcase_sheet`, `_links`) -- `content_for :title` "Me"; a root `<div class="me" data-controller="me" data-me-back-value="<active key>" data-action="back-picker:equipped->me#wear">` holding the profile (rendered with `editing: true`, `context: { from: "me" }`), one `<template data-me-target="back" data-key="<key>">` per unlocked back holding the preview's art (`card_back_image(row.back, "xs")`) and name, and the three sheets: title sheet (intro line, "No title" then titles grouped by rank under their rank heading, each a `button_to personalization_title_path, method: :patch, params: { title: "rank:kind:key" }` styled as a `filter-chip` with `aria-current="true"` on the worn one; empty line when none earned); back sheet (intro "Only you see it…", unlocked count, the picker; `open:` when `flash[:chosen_back]`); showcase sheet (one row per card: small face, title, ✕ `button_to card_showcase_path, method: :delete` labelled with the existing remove key, autofocus on the neighbour named by `flash[:removed_showcase_card]`; the "up to five cards" line, how to add one with "Add to showcase" and a link to the card list; `open:` when `flash[:removed_showcase_card]`); bottom `.plus__list` with How it works then Settings.
- [ ] `app/views/public_profiles/_summary.html.erb`, `_profile.html.erb`, `_showcase.html.erb`, `_achievements.html.erb`, `show.html.erb` -- `editing:` (default false): the title becomes an opener link (title text, or "Choose a title", plus a visible "Change" cue); under it the card back preview opener (`data-me-target="preview"`: art, name, "Only you", "Change"); the action button hidden; the showcase head gets an "Edit" opener and an empty section when no card; the achievements section gets a "See all achievements" link to `achievements_path` holding `#plus-achievements-badge`. Brother page passes `context: { brother: owner.token }` and stays as it renders today.
- [ ] `app/frontend/lib/me.ts` + `me.test.ts`, `app/frontend/controllers/me_controller.ts` -- module: the worn back state and `wear(state, detail)` returning the new state or null for an unknown/invalid/unchanged detail. Controller: on `wear`, apply it, write `data-worn-back` on its element and replace the preview target's art and name with a clone of the template whose `data-key` matches (no template: leave the preview).
- [ ] `back_picker_controller.ts` -- dispatch `equipped` (see Code Map).
- [ ] `bottom_sheet_component.rb/.html.erb` + `test/components/bottom_sheet_component_test.rb` -- `open:` keyword.
- [ ] `card_backs_controller.rb`, `profile_titles_controller.rb`, `personalization_refusal.rb`, `cards_controller.rb` -- redirects and the `from=me` browse.
- [ ] `shell_helper.rb`, `_player_chip.html.erb` -- Me screen wiring; menu "My profile" to `me_path`.
- [ ] `app/frontend/styles/me.css` + import after `back-picker.css`; prune page-only rules from `personalization.css` (delete the file if nothing is left) -- band openers, sheet rows, title choices as buttons; phone 390px without horizontal scroll.
- [ ] `config/locales/en.yml`, `fr.yml` -- `own_profiles.show.*` (title Me/Moi, change, choose title, card back only you, edit showcase, add hint, card list link, see all achievements, how it works, settings), `shell.player.profile` "My profile"/"Mon profil"; remove keys only the deleted views used (grep each first).
- [ ] Tests -- `test/controllers/own_profiles_controller_test.rb` (matrix rows Me, visitor, empty showcase, visitor-sees-same, old page, card detail back, one settings link, fr strings, no `\b\d+\b` database ids in openers/forms), `test/policies/own_profile_policy_test.rb`; fix the listed controller and integration tests to `/me`; `test/system/me_page_test.rb` replacing `personalization_test.rb` (keyboard move and drag on Me; title chosen and removed in its sheet; back equipped in the sheet updating the band preview with `window.stayedOnPage` kept; back restored from cache by Back; showcase card removed from its sheet, sheet reopened; Settings reached in one tap at 390x844).

**Acceptance Criteria:**
- Given a phone 390x844 on /me, when the title, the back preview or the showcase Edit is tapped, then the matching sheet opens as a modal dialog named by its title, and Escape returns focus to the opener.
- Given the page, when inspected, then exactly one link in `main` leads to `/settings`, and the settings page still shows language, sign-ins, data, deletion, support and legal.

## Implementation Notes

- `ProfileLoading` concern shared by `PublicProfilesController#show` and the new `OwnProfilesController#show`; public profile query counts unchanged.
- `/personalization` keeps its route name as a 301 to `/%{locale}/me`; its controller, policy, page views and `personalization.css` are gone, and so is `change_submit_controller.ts` (only the old title select used it).
- The card back opener reads "Card back · only you" (`own_profiles.show.card_back`); `personalization_scope` and `profile_title_options` helpers removed.
- With no published season, Me still shows the achievements section so the "See all achievements" link and `#plus-achievements-badge` stay on the page.
- `_profile` passes `editing: editing` and `worn_back: worn_back` explicitly: the shorthand at the end of an ERB tag broke packwerk's ERB parse.
- After a title choice the title opener takes autofocus; the title sheet is not sent open again.
- `test/system/personalization_test.rb` became `test/system/me_page_test.rb` (8 flows); `test/integration/shell_test.rb` only had its "My public profile" assertion changed to "My profile".
- Parallel test workers on this database need `PARALLEL_WORKERS=4` for the Ruby suite and `PARALLEL_WORKERS=1` for system tests (environment only).

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[defer]` Me is now cached by Turbo and holds `#plus-achievements-badge`, so after claiming rewards and pressing Back the restored Me shows the old count — real, but the tab bar's `#tab-me-badge` already goes stale the same way on every cached screen (pre-existing); exempting Me from the cache would drop the restore-by-Back behaviour the back picker relies on, so the fix is a cache policy choice. Deferred.
  - `[low]` `[reject]` the showcase sheet's rows keep the old order after an in-place drag until the page reloads — real but harmless (rows only offer removal by slug, which still targets the right card); fixing needs script to reorder server rows, more than a direct correction.
  - `[low]` `[patch]` tapping the title already worn re-ran `Game::ChooseProfileTitle` and showed a toast with nothing changed — the worn choice is now a `type="button"` with `data-action="bottom-sheet#close"`, outside any form; controller tests assert it.

## Design Notes

The back picker is reused as is inside the sheet; it reports a fact to the Me root by `dispatch`, and the root alone writes the preview (it owns that region) from its own templates, so neither controller reads the other's markup. The title and the showcase removal go through ordinary Turbo form submissions that redirect to /me: the page re-renders with the result and its toast, which is "shown at once" without new JSON endpoints. Sent-open sheets keep the player in the showcase or back sheet after a no-JS or removal round trip.

## Verification

Run every Rails command from this worktree with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w33_12` and `CHROME_BIN=/usr/bin/chromium` exported. Never run the whole system suite (it crashes this machine), only the files below. Do not commit.

**Commands:**
- `npm run test:js && npm run typecheck && npm run format:check && npm run lint:css` -- expected: pass
- `bin/rails test test/controllers test/components test/helpers test/integration test/policies` -- expected: pass
- `bin/rails test test/system/me_page_test.rb test/system/bottom_sheet_test.rb test/system/settings_test.rb` -- expected: pass
- `bin/rails zeitwerk:check && bundle exec packwerk check && bundle exec i18n-tasks missing && script/check_markup_apis && script/check_file_sizes && script/check_planning_references` -- expected: pass
- `bin/rubocop` on touched Ruby -- expected: no offenses

## Auto Run Result

**Summary:** the Me tab (`/me`, `OwnProfilesController#show`) renders the player's own public profile through the same partials as `/brothers/:token`, with the title, the card back (owner only) and the showcase each opened into the shared bottom sheet; a card back equipped in its sheet updates the band's preview at once through the `me` root controller; title choices and showcase removals redirect back to Me with their toast; the achievements section links to the full list with the unclaimed badge; How it works and one Settings link close the page. `/personalization` redirects for good to `/me`, the personalization page is gone, and the desktop player menu offers "My profile".

**Files changed:**
- `app/controllers/own_profiles_controller.rb`, `concerns/profile_loading.rb`, `app/policies/own_profile_policy.rb` -- the Me screen and its shared profile loading.
- `app/controllers/public_profiles_controller.rb`, `pages_controller.rb`, `cards_controller.rb`, `card_backs_controller.rb`, `profile_titles_controller.rb`, `concerns/personalization_refusal.rb` -- loading extracted, `pages#me` removed, redirects and the `from=me` card browse.
- `app/views/own_profiles/*` -- Me page, openers, three sheets, links.
- `app/views/public_profiles/_profile`, `_summary`, `_showcase`, `_achievements`, `show` -- `editing:` and `context:`.
- `app/views/personalizations/_back_picker.html.erb` -- unframed for the sheet; page views removed.
- `app/components/bottom_sheet_component.*` -- `open:` for sent-open sheets.
- `app/frontend/controllers/me_controller.ts`, `lib/me.ts` (+ test), `back_picker_controller.ts` -- live card back preview.
- `app/frontend/styles/me.css` (new), `personalization.css` (removed), `settings.css`, `entrypoints/application.css`.
- `app/helpers/shell_helper.rb`, `app/views/shell/_player_chip.html.erb`, `config/routes.rb`, `config/locales/en.yml`, `fr.yml`.
- Tests: new own profiles controller, policy and Me system tests; updated controller, integration and helper tests; personalization tests removed.

**Review:** 1 patch applied (low: the worn title only closes its sheet), 1 deferred (low: stale badge after Back), 1 rejected (low: showcase sheet order after a drag, harmless).

**Follow-up review recommendation:** false (patched: 0 high, 0 medium, 1 low).

**Verification:** `bin/ci` passed (rubocop, packwerk, i18n-tasks missing, typecheck, markup APIs, format, stylelint, planning references, file sizes, bundler-audit, brakeman, schema build and round trip, 4317 Rails tests, seeds); `npm run test:js` 874 passed; `bin/rails zeitwerk:check` clean; `test/system/me_page_test.rb`, `bottom_sheet_test.rb`, `settings_test.rb`, `card_detail_test.rb` green, Me and sheet tests re-run green after the patch.

**Residual risks:** desktop-width layout of the band openers was not looked at, only 390px; the full system suite was not run; the draft branch `profile-settings-rework` edits the same views and controllers with a different shape (own profile at `/brothers/:token` with dialogs, name moved out of settings), so merging both will conflict.

## Code Review

### 2026-11-04 — 0 decision-needed, 2 patch, 5 defer, 4 rejected

- [x] [Review][Patch] Pin that Me with no published season still links to the achievements and shows the no-season line [test/controllers/own_profiles_controller_test.rb]
- [x] [Review][Patch] Pin that a back worn with no season mark stamps none even earned in two seasons [test/controllers/card_back_seasons_controller_test.rb]
- [x] [Review][Defer] The owner has no link to the public profile visitors see, since the desktop menu entry became My profile — deferred: a UX choice for the author
- [x] [Review][Defer] Me no longer opts out of the Turbo cache: a stale achievements badge and a dialog restored open after Back — deferred: already recorded, settle on the iPhone pass
- [x] [Review][Defer] A showcase removal with no Referer lands on the card page instead of Me — deferred: low, pass a Me fallback if reported
- [x] [Review][Defer] Naming still points at the removed Personalization page (partials, locale keys, routes) — deferred: a rename for the refactor sweep
- [x] [Review][Defer] Desktop layout of the Me page and the sheets' accessibility names were not checked — deferred: iPhone and desktop pass

**Rejected**
- Old from=personalization links lose their back button: low, no live link uses it.
- The redirect from /personalization drops query strings: by design.
- A nil worn back raises: low, the shelf always has an active row.
- Magic numbers in me.css, duplicate strings, plan hygiene, session paths in the plan: low or edits the plan.
