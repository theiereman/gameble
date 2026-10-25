---
title: 'Profile and settings use the width of a large screen'
type: 'feature'
ticket: 30
created: '2026-10-25'
status: 'blocked'
baseline_revision: '27b677d308e8106cc52d312bb30f36340222094b'
route: 'oneshot'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On a desktop the Profil et paramètres screen (`app/views/settings/show.html.erb`, `.settings` capped at 520px in `app/frontend/styles/settings.css`) is one narrow column, the public profile summary above the settings panel, and leaves a wide screen empty (author, 2026-10-23, walkthrough finding 22). The friends screen fixed the same gap in 16.28; the wide screens should read alike.

**Approach:** Lay the screen out in the arrangement settled for Amis (`app/frontend/styles/friends.css`, DESIGN.md's Amis layout row): from 1180px a side area of 380px on the left and a main area taking the rest; from 900px the side area is 300 to 360px; one column under 900px, in the existing order. The side area holds the public profile summary; the main area, the larger one, holds the settings panel (language, visibility, motion, session, data, account, support, "Mentions légales"), where the card-back picker will join it when it is built (it is not on the screen yet: no picker exists to place). The cap of 520px goes; the settings' markup, behavior, strings, back button and language links stay as they are. A system test checks the desktop arrangement (summary left, settings right and wider, no horizontal scroll) and the phone's one column; DESIGN.md's Profil et paramètres layout row and EXPERIENCE.md's Profil et paramètres row follow.

</intent-contract>

## Implementation Notes

Oneshot (pinned): one screen's wrapper markup and stylesheet, one system test and two doc rows. No model, operation, route, policy or string changes.

- Files touched: `app/views/settings/show.html.erb` (`.settings__layout` grid of `.settings__side`, holding the profile summary, and `.settings__main`, holding the settings panel; the panel's rows are only re-indented; the dialogs stay after the section), `app/frontend/styles/settings.css` (the 520px cap dropped; the layout rules mirror `friends.css`: `380px minmax(0, 1fr)` with the wide column gap from 1180px, `clamp(300px, 30vw, 360px)` with the medium gap from 900px, one column under 900px with the former 24px gap between summary and panel), `test/controllers/settings_controller_test.rb` (the structure assertion follows the two areas), `test/system/settings_test.rb` (two tests: desktop at 1400px and 1000px, reached from Amis through the player menu, then the back button returns to Amis; the phone at 390px), DESIGN.md (Profil et paramètres layout row: as Amis, the summary in the side area, the settings in the main area where the back picker joins them when built; left 300 to 360px; one column summary then settings), EXPERIENCE.md (Profil et paramètres row of the Information Architecture).
- Decisions: the summary takes the side area and the settings the main one: the card-back picker does not exist yet (the view's comment says it comes with its own story), so a main area waiting for it would stay empty; DESIGN.md's former row (settings in the side, the picker in the main area) is replaced. The layout rules are copied from `friends.css` rather than shared, so this build stays out of the friends screen that 16.29 changes in parallel. Under 900px the column is no longer capped at 520px, as on Amis.
- Not on the screen: the card-back picker (no picker is built); the ticket's "card-back picker reachable" has nothing to check yet.

### Verification run (2026-10-25)

- `bin/rails test test/controllers/settings_controller_test.rb test/controllers/accounts_controller_test.rb`: 73 runs, pass.
- `bin/rails test test/system/settings_test.rb`: 13 runs, 140 assertions, pass (the language links, the back button, the support and legal links, sign-out, visibility, delete, motion, PLUS, and the two new layout tests, the latter repeated three times, green each time). `bin/rails test test/system/shell_test.rb`: 23 runs, pass. Screenshots at 1400px (summary 380px left, settings panel right), 1000px (side 300px) and 390px (one column, summary first) checked by eye.
- `npm run test:js` (580 tests), `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/rubocop`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: pass.
- `PARALLEL_WORKERS=2 bin/rails test`: 3188 runs, 0 failures, 0 errors.

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `bin/rails test test/controllers/settings_controller_test.rb test/controllers/accounts_controller_test.rb` -- expected: pass
- `bin/rails test test/system/settings_test.rb test/system/shell_test.rb` -- expected: pass
- `npm run test:js`, `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bin/rubocop`, `PARALLEL_WORKERS=2 bin/rails test` -- expected: pass

**Manual checks (if no CLI):**
- Screenshots from the settings system tests at 1400px (summary on the left, settings panel on the right and wider) and 390px (one column, summary then settings).

## Auto Run Result

Status: blocked
Blocking condition: no subagents (the review step's Quick lens needs a subagent this session cannot launch; the coordinating session runs the review)

- Summary: on a desktop the Profil et paramètres screen takes the friends screen's arrangement: the public profile summary in a side area on the left (380px from 1180px, 300 to 360px from 900px) and the settings panel in the larger area on the right; one column under 900px, the summary first. The settings, the language links and the back button are unchanged.
- Implementation commit: 787298805324389951a9cbcd25249a2d05bb978a, on `build/16.30-settings-wide` from 27b677d308e8106cc52d312bb30f36340222094b.
- Files: `app/views/settings/show.html.erb` (side and main wrappers), `app/frontend/styles/settings.css` (the layout, the 520px cap dropped), `test/controllers/settings_controller_test.rb` (structure assertion), `test/system/settings_test.rb` (desktop and phone layout tests, the back button), DESIGN.md (layout row) and EXPERIENCE.md (Information Architecture row).
- Review: not run (`no subagents`).
- Verification: see Implementation Notes, Verification run: settings controller tests, settings and shell system tests, vitest, typecheck, zeitwerk, packwerk, i18n-tasks, rubocop, brakeman and the full suite (3188 runs) pass.
- Residual risks: the card-back picker is not built, so the ticket's "card-back picker reachable" has nothing to check; the author checks the layout on staging in French and in English, including a long name and a full showcase in the 300px side area.
