---
title: 'Return to the previous screen without reverting the selected language'
type: 'bugfix'
ticket: ''
created: '2026-10-19'
status: 'built'
baseline_revision: '273ecdd51d160c6c3c60984649574fe556f7565a'
route: 'full'
route_source: 'pinned'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - _bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md
  - AGENTS.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After a player changes the interface language in settings and returns to the screen they came from, the old screen's locale can take precedence and undo the new selection. This makes the language control appear not to persist.

**Approach:** Make the in-app return action reach the same previous screen in the language currently selected. Keep existing same-language history restoration behavior intact.

## Boundaries & Constraints

**Always:** Keep locale in the URL as the source of truth for each request. Keep the previous-screen label and destination aligned. Preserve existing back behavior when the history trail is in the current locale.

**Never:** Add a separate persisted language preference or change the meaning of direct links. Do not change phone contextual navigation unless the investigation shows it shares the bug.

</frozen-after-approval>

## Code Map

- `app/frontend/lib/history_trail.ts` -- records pathnames and labels and selects the desktop previous screen; it currently stops when a prior entry uses another locale. Switching `/fr/settings` to `/en/settings` creates adjacent entries for the same screen, so return must skip the old-locale settings entry and reach the prior screen in English.
- `app/frontend/controllers/previous_screen_controller.ts` -- displays and handles the desktop return button, using browser history when the previous screen is known.
- `app/views/shell/_top_bar.html.erb` -- renders the previous-screen anchor and controller binding.
- `app/frontend/lib/history_trail.test.ts` -- unit coverage includes the current behavior of stopping at a language change; revise it to cover return in the selected locale and preserve same-locale cases.
- `app/views/settings/show.html.erb` -- language links navigate to the same settings screen under the chosen locale.
- `_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md` -- specifies that the desktop back returns to the previous screen and that language follows the selected locale.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/history_trail.ts` -- identify the previous labeled screen across a locale switch and provide a destination using the current locale -- the selected language must remain in effect.
- [x] `app/frontend/controllers/previous_screen_controller.ts` -- use navigation that preserves the current locale when returning across a locale boundary, while retaining history restoration for same-locale returns.
- [x] `app/frontend/lib/history_trail.test.ts` -- cover cross-locale return, missing or hub entries, and unchanged same-locale history behavior.

**Acceptance Criteria:**
- Given a player on a French screen who opens settings and selects English, when they use the in-app return button, then they reach the previous screen in English and the selected language remains active.
- Given a player who changes no language, when they use the in-app return button, then it restores the previous screen using the existing browser-history behavior.
- Given a direct settings visit with no recorded previous screen, when the page loads, then the return button remains hidden as before.

## Implementation Notes

- Cross-locale return targets use the selected locale and matching server-rendered screen labels; same-locale returns still restore browser history.
- The focused history-trail tests pass (22 tests). The full JavaScript suite has additional failures in unrelated tests and temporary Vitest cache access.

## Plan Change Log

## Review Triage Log

- `false` — The review expected a contextual return button to appear when the previous screen is the hub. The experience specification explicitly hides that button for the hub, and the top bar's home link is rendered with the current locale, so the English hub remains reachable without reverting the language.
- `false` — The review warned that localized route suffixes may differ. The routes are declared once inside `scope ":locale"` in `config/routes.rb`; the locale is the first path segment and the route suffix is shared, so rewriting `/fr/friends` to `/en/friends` matches the application's routing model.

## Verification

**Commands:**
- Focused `history_trail.test.ts` run -- passed (22 tests).
- `git diff --check` -- passed.
- `npm run test:js` -- failed in unrelated collection-grid and wordmark-shine assertions and several suites reported Vitest temporary-cache access errors.
