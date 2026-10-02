---
title: 'Attic page shell'
type: 'feature'
ticket: '8'
created: '2026-10-02'
status: done
baseline_revision: '3aa9183eee4963cd458aa9adff644f3de1fda963'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/spec-gameble/brotherhood-tone.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The home page is a placeholder. EXPERIENCE.md makes the attic the landing screen after sign-in and a page open to signed-out visitors, and gives staff a back-office; none of these exist.

**Approach:** Turn the localized home page into the attic: a wide room drawn in plain CSS after `mockups/attic.html`, with its six scenery objects named and the chest in the middle, panned sideways on a phone and opening centred on the chest. The same page serves signed-in players and signed-out visitors (who see the Steam sign-in button in the status band and an invitation in the room). Add an empty back-office page that only moderators and administrators can open, linked from the status band for staff.

## Boundaries & Constraints

**Always:**
- The attic is the page at `/:locale` (route `home`), so a sign-in that starts there returns there.
- The room follows DESIGN.md "The attic" and the mock's composition: brick back wall, chevron parquet, the window at the very left edge half cut, and the six objects of the table (lectern with grimoire, notice board, medal display, standing mirror, carved trade table, iron-bound chest on the floor, centred). Plain CSS on the 2px grid using the design tokens; no images, no blur, no gradients beyond hard bands.
- Each object carries its translated name as text (never a picture alone). Objects lead nowhere yet, so they are not links or buttons; their names are always visible.
- On a narrow screen the room keeps its width and scrolls horizontally inside its frame; on load it is scrolled so the chest is centred (a Stimulus controller in TypeScript). The status band stays visible.
- The sample island from story 1.5 stays mounted on the attic, restyled as a small season plaque (its existing strings), so its tests keep proving the toolchain.
- Signed-out: the room shows an invitation text plate to sign in to open packs (the sign-in button itself stays in the status band). Signed-in: no invitation.
- Back-office: `GET /:locale/back-office`, a `BackOffice::DashboardController#show` with its own policy: moderator or administrator only; a visitor is sent to sign in, a player gets 403 (story 1.7's refusal handling). The page shows a heading and an empty-state line; nothing else. A status band link to it appears only for staff.
- All copy in `en.yml` and `fr.yml`, Brotherhood tone. Policy tests include the signed-out visitor (AD-22).

**Never:**
- No pack opening, chest count, timer, daily bonus, feed, gauge or counters content. No screens behind the objects. No final art.
- No moderation or import tools in the back-office (epics 2 and 7).
- No change to sign-in, roles or ban logic.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Signed-out attic | `GET /fr`, signed out | 200; the room with six named objects and the chest; the sign-in invitation; the status band sign-in button; no back-office link | No error expected |
| Signed-in attic | `GET /en`, signed in as a player | 200; the room; no invitation; sign-out button; no back-office link | No error expected |
| Landing after sign-in | sign-in started on `/fr` | redirect to `/fr`, which renders the attic | No error expected |
| Staff link | `GET /fr` as moderator or administrator | the status band shows the back-office link | No error expected |
| Back-office, staff | `GET /fr/back-office` as moderator, then as administrator | 200; back-office heading and empty state | No error expected |
| Back-office, player | `GET /fr/back-office` as a player | 403 | Pundit refusal |
| Back-office, visitor | `GET /fr/back-office` signed out | redirect to `/fr` with the sign-in alert | Pundit refusal |
| Phone width | browser 390px wide opens `/en` | the room scrolls horizontally and starts with the chest centred | No error expected |

</intent-contract>

## Code Map

- `app/views/pages/home.html.erb` -- current placeholder (heading, intro text plate, two buttons, `turbo_mount("SampleIsland", props: { data: { season: 1 }, strings: {...} })`); becomes the attic.
- `app/controllers/pages_controller.rb` -- `home` with `authorize :page, :show?` (headless `PagePolicy`).
- `app/controllers/application_controller.rb` -- Pundit, `verify_authorized`, `current_player` (ban-checked), refusal handling (visitor → redirect home with `authorization.sign_in_required`; player → 403), `default_url_options` with locale.
- `app/policies/application_policy.rb` -- deny by default; `visitor?`, `player?`, `moderator?` (moderator or administrator), `administrator?`. `test/policies/*` show the testing pattern.
- `app/views/layouts/application.html.erb` -- status band with gauge and counters `<section>`s; sign-in form or sign-out button (`ButtonComponent` with `method:`); flash region; `<main class="main">`.
- `app/components/{text_plate,button}_component.*` -- DESIGN.md components.
- `app/frontend/entrypoints/application.ts` -- registers Stimulus controllers from `app/frontend/controllers/**/*_controller.ts` via `stimulus-vite-helpers` (none exist yet).
- `app/frontend/entrypoints/application.css`, `app/frontend/styles/tokens.css` -- tokens and component styles; add the attic styles in a new `app/frontend/styles/attic.css` imported by the entrypoint.
- `test/fixtures/accounts/players.yml` -- `player`, `moderator`, `administrator`, `banned` fixtures; `test/controllers/sessions_controller_test.rb` and `authorization_test.rb` show how tests sign in (OmniAuth test mode helpers).
- `test/controllers/pages_controller_test.rb` -- asserts `h1` text and Vite tags on `/en`, the island props on `/fr`; update for the attic.
- `test/system/sample_island_test.rb`, `test/application_system_test_case.rb` -- island renders in both locales, survives a Turbo visit through the home page's "Report for duty" button (`ButtonComponent` link to `home_path`); the attic drops those buttons, so adapt the test to start the Turbo visit with `Turbo.visit(location.href)` through `execute_script`, keeping its `turbo:load` counter and marker checks.
- `_bmad-output/initiative-gameble/ux-gameble/mockups/attic.html` -- program-drawn composition reference (HTML/CSS, desktop and phone).

## Tasks & Acceptance

**Execution:**
- [x] `app/views/pages/home.html.erb`, `app/frontend/styles/attic.css`, `app/frontend/entrypoints/application.css` -- the attic room, objects, chest, invitation, season plaque -- the landing screen
- [x] `app/frontend/controllers/attic_controller.ts` -- centre the chest on connect when the room overflows -- phone pan
- [x] `config/routes.rb`, `app/controllers/back_office/dashboard_controller.rb`, `app/views/back_office/dashboard/show.html.erb`, `app/policies/back_office/dashboard_policy.rb` -- staff-only shell -- R9
- [x] `app/views/layouts/application.html.erb` -- back-office link for staff in the status band -- staff reach it
- [x] `config/locales/{en,fr}.yml` -- object names, invitation, plaque, back-office copy; remove keys no longer used -- AD-18
- [x] `test/controllers/pages_controller_test.rb`, `test/controllers/back_office/dashboard_controller_test.rb`, `test/policies/back_office/dashboard_policy_test.rb` -- every request row of the matrix -- proof
- [x] `test/system/attic_test.rb`, `test/system/sample_island_test.rb` -- phone-width row; the island tests still pass -- proof in a browser

**Acceptance Criteria:**
- Given a player who signs in from the attic, when the sign-in completes, then they land on the attic.
- Given a signed-out visitor, when they open the attic, then they see the room and the sign-in button and cannot reach the back-office.
- Given the suite, when tests, system tests, Packwerk, i18n-tasks (missing and unused), RuboCop, zeitwerk, Brakeman and the type check run, then all pass.

## Implementation Notes

- The room is drawn with solid-colour background layers (hard-edged `linear-gradient(c 0 0)` rectangles, hard-stop radial ellipses for round scenery, hard conic stops for brick joints), outlined in ink by four unblurred `drop-shadow`s. Brick, parquet, sky and haze colours are not DESIGN.md tokens; they live as `--attic-*` properties scoped to `.attic` in `attic.css`, taken from the mock's proposal.
- The chest is named ("The chest" / "Le coffre") like the five other objects. The page h1 is visually hidden; the room frame is a focusable, labelled region so keyboard users can pan it.
- The back-office link is shown when `policy([:back_office, :dashboard]).show?`, so the link and the page share one rule.
- `i18n-tasks unused` already reported the ten `errors.*` keys at baseline (they are built from failure codes at runtime); `config/i18n-tasks.yml` now ignores `errors.*` for unused so the check passes.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 8 findings — high 0, medium 3, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The back-office had no back button to the attic (EXPERIENCE.md, DESIGN.md: every screen but the attic), and the status band linked the back-office to itself — a page asks the layout for the back button (`content_for :back_button`), shown at the left of the status band; the back-office link is hidden on the back-office; both tested.
  - `[medium]` `[patch]` Gold and rarity colours were used as scenery colours, against DESIGN.md — replaced by brass tokens and scoped `--attic-*` scene properties (iron, glass, sky).
  - `[low]` `[reject]` `attic.css` adds raw `--attic-*` colours outside the DESIGN.md tokens — placeholder scene palette, scoped to `.attic` and named, recorded in the Implementation Notes; the final generated art replaces it.
  - `[low]` `[patch]` `.attic__invitation { left: 355px }` was off the 2px grid — now even values.
  - `[medium]` `[patch]` The invitation plate touched the notice board's French name plate — moved, notice board and medal display raised; clear in both locales on the screenshots.
  - `[low]` `[patch]` The room frame was a tab stop on desktop where nothing scrolls — the Stimulus controller sets `tabindex` only when the room overflows; the system test checks both widths.
  - `[low]` `[reject]` `ignore_unused: errors.*` hides every failure key from `i18n-tasks unused` — the keys are built at runtime from failure codes, CI runs `missing` only, and listing each key by hand is upkeep for little gain.
  - `[low]` `[patch]` The attic system test copied the driver's screen size — shared `ApplicationSystemTestCase::SCREEN_SIZE`.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- expected: all green
- `npm run typecheck && bin/vite build` -- expected: clean
- `bundle exec i18n-tasks missing && bundle exec i18n-tasks unused` -- expected: none
- `bundle exec packwerk check && bin/rubocop && bin/rails zeitwerk:check && bin/brakeman -q --no-pager` -- expected: clean

**Manual checks (if no CLI):**
- Screenshot `/fr` at desktop width and at 390px from the system test (`take_screenshot`) and look at it: the room reads as a room, the chest is centred on the phone.

## Auto Run Result

**Summary:** The localized home page is now the attic: a wide room drawn in plain CSS after the mock (bricks, chevron parquet, half-cut window), six named scenery objects with the chest centred, the season plaque island, and a sign-in invitation for visitors. On a phone the room pans sideways and opens centred on the chest. Staff reach an empty back-office at `/:locale/back-office` from the status band; other screens show a back button to the attic.

**Files changed:**
- `app/views/pages/home.html.erb`, `app/frontend/styles/attic.css`, `app/frontend/entrypoints/application.css` -- the attic
- `app/frontend/controllers/attic_controller.ts` -- chest centring and conditional tab stop
- `config/routes.rb`, `app/controllers/back_office/dashboard_controller.rb`, `app/views/back_office/dashboard/show.html.erb`, `app/policies/back_office/dashboard_policy.rb` -- staff-only shell
- `app/views/layouts/application.html.erb` -- back button, staff link
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- attic and back-office copy; `errors.*` ignored by `unused`
- `test/controllers/**`, `test/policies/back_office/*`, `test/system/{attic,sample_island}_test.rb`, `test/application_system_test_case.rb` -- matrix rows and review fixes

**Review findings:** 6 patches applied (3 medium, 3 low); 0 deferred; 2 rejected (scene palette outside tokens, `errors.*` unused-ignore).

**Follow-up review recommended:** true — three medium patches. The open risk is visual: the room was redrawn after review (colours and positions) and has only been checked on two screenshots, in French at desktop width and in English at phone width.

**Verification:** `bin/rails test` (142 runs, 0 failures), system tests (5 runs, 0 failures), typecheck, `bin/vite build`, i18n-tasks, Packwerk, RuboCop, zeitwerk, Brakeman clean; screenshots inspected.

**Residual risks:** The attic copy is the implementer's wording in the Brotherhood tone and awaits the author's read. The tab stop is decided on load, not on resize.
