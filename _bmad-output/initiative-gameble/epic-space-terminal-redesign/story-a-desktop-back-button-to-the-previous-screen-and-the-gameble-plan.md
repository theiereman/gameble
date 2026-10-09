---
title: 'A desktop back button to the previous screen, and the GAMEBLE logo leads to the hub'
type: 'feature'
ticket: '18'
created: '2026-10-09'
status: 'built'
baseline_revision: '24ff3e7d5c6d8d698c5f66d8d22d1d4ccf268683'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 1
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** On desktop the only way out of a screen is "◀ PONT" to the hub; a player who went hub → collection → card detail cannot step back to the collection without the browser's Back.

**Approach:** On desktop (≥ 720px) the top bar's logo and "GAMEBLE" become a link to the hub on every non-hub screen, replacing "◀ PONT", followed by a divider, a back button that does `history.back()` and names the previous screen by its short label, then the screen title. The previous screen and its label come from the existing per-tab history trail, extended to record each entry's screen label. The phone keeps today's top bar.

## Boundaries & Constraints

**Always:** the back button shows only when the history entry right before the current one was recorded by this document and carries a screen label; the hub and pages without a label record none, so the button stays hidden after them, after a direct link, a new tab or a reload. Its accessible name says it goes back ("Back: Collection" / "Retour : Collection"). The GAMEBLE link and the back button sit inside `.top-bar__start`, so the navigation lock disables them during an opening. Every new string in `en.yml` and `fr.yml`. Server HTML carries no `style` attribute.

**Never:** change anything under 720px (the "◀ PONT" button and `phone_back` links keep their current rules); make the hub's brand a link; read the previous screen from `Referer` or write anything on a GET.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Back named | Desktop: hub → collection → a card detail | Card detail shows "◀ COLLECTION"; it returns to the collection restored (filters, page, scroll) | No error expected |
| After the hub | Desktop: hub → friends | No back button; GAMEBLE link opens the hub | No error expected |
| No earlier screen | Card detail opened by direct link, new tab or reload | No back button | No error expected |
| Detail stepping | Card detail ◀ ▶ (replaced entries) | Back label still names the screen before the detail | No error expected |
| Opening | Booster opening or revealing | GAMEBLE link and back button locked | Clicks swallowed |
| Storage refused | sessionStorage throws | No back button | Trail reads empty |
| Phone | < 720px, any screen | Top bar identical to today | No error expected |

**Decisions (author, 2026-10-09):** the booster island's own "Retour au pont" link stays as it is, and stays the focus target on an empty reserve. Short screen labels: Collection/Collection, Set/Set, Card/Fiche, Booster/Booster, Trades/Échanges, Friends/Amis, Profile/Profil (friend profile, public profile, settings), Feed/Fil, Legal notice/Mentions légales, More/Plus, Back-office/Back-office. The plan is kept whole above 1600 tokens.

**Decisions after review (author, 2026-10-09):** on desktop the logo and "GAMEBLE" link to the hub on every non-hub screen with app chrome, including those without a back button (More opened on a desktop, the invitation pages, the refusal page); the public card page keeps its plain brand, and the phone keeps the plain brand where it shows it today. A screen title cut with an ellipsis between 720 and about 1000px is accepted. Review findings are patched on the current code rather than reverted.

</frozen-after-approval>

## Code Map

- `app/views/shell/_top_bar.html.erb` -- back_button branch renders the "Bridge" `ButtonComponent` (href `home_path`), `yield :phone_back`, `.top-bar__title`; else `.top-bar__brand` (logo + name, not a link). Only `layouts/application.html.erb:17` renders it.
- `app/frontend/styles/shell.css` -- `.top-bar__start` (200), `.top-bar__phone-back` hidden (220), `.top-bar__brand` (224), `.top-bar__title` (240), `[data-navigation-locked]` (308); phone block `@media (max-width: 719px)` (1264): Bridge hidden when `--phone-back` (1306).
- `app/frontend/lib/history_trail.ts` (+ `history_trail.test.ts`) -- sessionStorage trail `{restorationIndex → pathname}`, reset on each full load and bfcache `pageshow`; `recordEntry`, `stepsBackTo`, `entryAfter`, `currentIndex`. Extend it to keep a label per entry; keep current exports' behavior.
- `app/frontend/controllers/history_back_controller.ts` -- module-level recorder (turbo:load, turbo:frame-load, pageshow) used app-wide; the place to record the label too. Its `back` action is the phone's contextual back; leave it as is.
- `app/frontend/controllers/navigation_lock_controller.ts` -- locks every `a[href], button` inside `.top-bar__start` on `gameble:navigation-locked`.
- `app/helpers/shell_helper.rb` -- shell helpers (`back_office_page?` at 53); the hub check is inline in `shell/_tab_bar.html.erb:10` (`pages#home`).
- Views setting `content_for :back_button`: library/show, library/set, cards/show (non-public), boosters/show, packs/show, trades/_screen, friends/show, friend_profiles/show and unavailable, public_profiles/show and set, feeds/show, settings/show, pages/legal, back_office/*.
- `config/locales/{en,fr}.yml` -- `shell.top_bar` (11-13: `brand`, `back`); no short screen-label keys exist.
- Tests on the top bar: `test/integration/shell_test.rb` (59-62, 115-119, 203, 270); controller tests asserting `.top-bar__start > a.button--secondary[href='/en']` (library, public_profiles, cards, back_office/dashboard, settings) still hold, the Bridge stays in the DOM; system tests clicking or locating it at desktop size: `booster_test.rb` (152, 157, 556-600), `shell_test.rb` (248, 357), `hub_test.rb` (270, 290), `library_test.rb` (55, 94), `card_detail_test.rb` (125, 283), `share_card_test.rb:194`, `card_preview_test.rb:165`.

## Tasks & Acceptance

**Execution:**
- [x] `app/helpers/shell_helper.rb` -- add `shell_screen_label`: the short label of the current page from `controller_path`/`action_name`, nil for the hub and unlisted pages -- one table instead of fifteen views.
- [x] `config/locales/en.yml`, `fr.yml` -- `shell.screens.*` short labels (Collection/Collection, Set/Set, Card/Fiche, Booster/Booster, Trades/Échanges, Friends/Amis, Profile/Profil, Feed/Fil, Legal notice/Mentions légales, More/Plus, Back-office/Back-office) and `shell.top_bar.home` ("gameble, command bridge" / "gameble, pont de commandement"), `shell.top_bar.previous` ("Back:" / "Retour :").
- [x] `app/views/shell/_top_bar.html.erb` -- carry the page's label on the top bar (data attribute); in the back_button branch render the brand as a link to `home_path` (desktop only), a divider, the Bridge button (phone only), `phone_back`, a hidden desktop back link driven by a new controller, then the title.
- [x] `app/frontend/styles/shell.css` -- brand link, divider and back link styles; hide brand link, divider and back link under 720px and the Bridge button from 720px.
- [x] `app/frontend/lib/history_trail.ts`, `history_trail.test.ts` -- record and read a label per entry (`labelBefore(index)`), pruned like pathnames; vitest for record, read, missing entry, refused storage.
- [x] `app/frontend/controllers/history_back_controller.ts` -- record the top bar's label with each entry.
- [x] `app/frontend/controllers/previous_screen_controller.ts` -- on connect, read the label before the current entry; when present, set the link's text and `href` (the recorded pathname) and unhide it; on a plain click, `history.back()`.
- [x] `test/integration/shell_test.rb`, `test/system/shell_test.rb` and the system tests listed in the Code Map -- reach the hub through the GAMEBLE link on desktop; new system tests for the matrix rows (named back, after the hub, direct link, detail stepping, opening lock, phone unchanged).

**Acceptance Criteria:**
- Given a desktop window on a non-hub screen, when the page loads, then the logo and "GAMEBLE" form one link to the hub and no "◀ PONT" button is visible.
- Given a phone window, when any screen loads, then its top bar shows what it shows today (Bridge button or contextual back, title) and neither the GAMEBLE link nor the desktop back button.
- Given `bin/rails test`, `bin/rails test:system`, `npm run test:js`, when run, then all pass.

## Implementation Notes

- Trail entries are now `{ pathname, label? }`; `entryBefore`/`labelBefore` mirror `entryAfter`; unreadable entries are dropped on read. `currentScreenLabel()` reads `data-screen-label` from the top bar; `trade_board_controller.ts` passes it too when it replaces the URL.
- The Bridge button is hand-written with `top-bar__bridge` (ButtonComponent takes no class) and stays in the DOM, hidden from 720px. The back link renders without `href` and `hidden`; `previous_screen_controller.ts` fills it on connect. Its accessible name comes from a visually hidden "Back:" span plus the label.
- Label table: `library#show` Collection, `library#set` and `public_profiles#set` Set, `cards` Card, `boosters`/`packs` Booster, `trades` Trades, `friends` Friends, `friend_profiles`/`public_profiles`/`settings` Profile, `feeds` Feed, `pages#legal` Legal notice, `pages#more` More, `back_office/*` Back-office.
- Also updated `test/controllers/back_office/dashboard_controller_test.rb` (asserted the Bridge as `:first-child`). New system tests sit in `test/system/shell_test.rb` (named back with detail stepping, after the hub, reload, direct link, refused storage, phone) and `test/system/booster_test.rb` (back button locked during an opening).

## Plan Change Log

## Review Triage Log

Pass 1 (quick lens): high 0, medium 3, low 1, false 0, maybe-false 0.

| # | Finding | Verdict | Route | Evidence |
|---|---|---|---|---|
| 1 | A live refresh (morph) empties and hides the back button | medium | patch | `live_refresh_controller.ts:43` refreshes friends and trades with `method: "morph"`; the morph restores the server's `hidden` link on the same element and Stimulus does not reconnect it; the reviewer reproduced it. Fix: sync again on `turbo:morph`. |
| 2 | Desktop non-hub screens without `back_button` (More, invitation pages, refusal page) keep a plain brand, no link to the hub | medium | intent_gap | The intent says every non-hub screen; the plan only changed the back_button branch; which screens count (the public card page has no app chrome and its tests assert no link) is not settled. |
| 3 | The screen title truncates between 720 and about 1000px | medium | intent_gap | Measured by the reviewer: "COLLECT…" at 900px in French; the logo, name, divider and back button now share the left side; DESIGN.md's narrower-width rules say nothing about it. |
| 4 | New explanatory comments break the repo rule to comment only external constraints | low | patch | AGENTS.md Policy; comments in `previous_screen_controller.ts`, `shell_helper.rb`, `shell.css`, `shell_test.rb`, `history_trail.test.ts`; a wrapped over-long line in `history_back_controller.ts`. Fix: delete them, rewrap. |

Patches applied (loop 1): findings 1 and 4 patched; findings 2 and 3 settled by the author (decisions in the frozen block), 2 patched, 3 accepted as is. Re-verified: vitest 214, bin/rails test 2135, system tests 180, zeitwerk, packwerk, i18n-tasks, rubocop clean.

## Design Notes

The trail is trusted only for entries of the current document (see the comment in `history_trail.ts`), so a reload hides the back button: hiding is the safe failure, never a wrong `history.back()`. `history.back()` rather than `history.go(-steps)` because the button's target is by definition the previous entry. Focus after this back follows the existing restore rule (`focusReturnLink`, card links only); extending it is not this story.

## Verification

**Commands:**
- `npm run test:js` -- expected: history_trail tests pass
- `bin/rails test` -- expected: green
- `bin/rails test:system test/system/shell_test.rb test/system/booster_test.rb test/system/hub_test.rb test/system/library_test.rb test/system/card_detail_test.rb test/system/share_card_test.rb test/system/card_preview_test.rb` -- expected: green
- `bin/rails zeitwerk:check` and `bundle exec packwerk check` -- expected: no offences
