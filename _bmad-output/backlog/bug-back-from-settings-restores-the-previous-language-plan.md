---
title: 'Back after a language change returns to the previous screen in the chosen language'
type: 'bugfix'
ticket: 'bug-back-from-settings-restores-the-previous-language'
created: '2026-10-19'
status: done
baseline_revision: '32fee1d122754f42610d4e35418a8912af0ef370'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The locale is the first URL segment, and every history entry keeps the URL it was shown under. After a player switches the language in the settings, browser Back (and any history-based back) returns to entries recorded in the old language, so the previous screen opens in French again; the language link also pushes a second settings entry, so the first Back lands on the old-language settings. The desktop back button was patched (ee85f8b) to visit the previous screen in the new language, but it pushes a new entry, and the browser's own Back was left as it was.

**Approach:** The language link replaces the settings entry instead of pushing one. Any return through history (a Turbo restore visit, a back/forward document load, a back/forward-cache restore) to an entry whose URL reads in another language than the one shown last in the tab is turned into a replace visit of the same address in the shown language. The desktop back button then always goes back through history, as without a language change. Back without a language change is unchanged.

</intent-contract>

## Implementation Notes

Oneshot: about 100 lines across a new pure module with its vitest, the entrypoint wiring, one view attribute and the desktop back button's simplification.

- Cause: the locale lives only in the URL (`scope ":locale"`), the language links (`app/views/settings/show.html.erb`) are plain Turbo advance visits, and Turbo restore visits replay old-locale URLs; `previous_screen_controller.ts` visited the translated path as a new entry, out of step with browser Back.
- `app/frontend/lib/history_trail.ts` keeps translating the previous screen's label and href; `localeChanged` goes, since the back button always uses `history.go`.
- Built: `app/frontend/lib/locale_return.ts` (new, wired from `app/frontend/entrypoints/application.ts`) remembers the locale of each localized page shown in the tab (sessionStorage), and turns a Turbo restore visit, a back/forward document load or a back/forward-cache restore to an address in another locale into a replace visit of the same address in that locale. The restore is redirected in a microtask: Turbo sets its restoration index to the popped entry only after `turbo:visit`, and the cached snapshot render waits for an animation frame, so the old-language page is never painted. `app/views/settings/show.html.erb`: the language links carry `data-turbo-action="replace"`. `app/frontend/controllers/previous_screen_controller.ts`: always `history.go`.
- Surprise: Turbo renders a cached snapshot with the live `<html lang>` (the snapshot reads `lang` from the current document), so `document.documentElement.lang` cannot tell which language was shown; the URL's first segment is used instead.
- Headless Chrome before the fix: browser Back from `/en/settings` showed `/fr/settings`, then `/fr/library`, in French; the app back pushed `/en/library`, after which browser Back returned to `/en/settings`. After: app back and browser Back both reach `/en/library` in English, then `/en`; forward stays English; a full page load in between (the motion form) is rewritten as well; with no language change Back restores `/fr/library` as before.

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 6, false 0, maybe-false 0
- findings:
  - `medium` `patch` `package-lock.json` renamed to the worktree directory by `npm install` — reverted.
  - `low` `patch` The previous-screen skip of the same path in the other locale is dead once the language link replaces its entry, and the tests built the old pushed pair — skip removed (an old-locale settings entry is skipped by its label anyway), tests rewritten to the replaced-entry trail with a case for the shape the fix produces.
  - `low` `reject` The history wiring of `keepLocaleOnReturn` has no automated test — vitest runs in node and system tests are disabled; a DOM and Turbo harness would add more than it checks. Covered by the headless Chrome run below; the Turbo ordering it relies on is named in a one-line comment.
  - `low` `reject` Back after a language change opens the previous screen at the top, without the return focus — the page is fetched anew in the other language, so there is no snapshot to restore; carrying the scroll across would add state for a rare path. The acceptance criteria hold.
  - `low` `reject` The rewrite also follows an other-language address typed or pasted into the same tab — the settings links are the only in-app language switch, and telling a typed address from a choice would add state; Back then keeps the language read last, which is the same rule. Left to the author.
  - `low` `patch` Locale path logic duplicated with `history_trail.ts` — `addressInShownLocale` now uses its exported `inLocale`; `ROUTED_LOCALES` mirrors the routes' `en|fr`, kept since the client has no other source for the list.
  - `low` `patch` The view comment line ran past the block's wrap — rewrapped. The storage-refusal catch comment stays: a refused sessionStorage is a browser constraint, and `history_trail.ts` uses the same form.

## Auto Run Result

- Summary: the language links replace the settings entry; `app/frontend/lib/locale_return.ts` turns any return through history (Turbo restore, back/forward document load, back/forward-cache restore) to an address in another locale than the one read last in the tab into a replace visit of that address in that locale; the desktop back button always goes back through history.
- Files: `app/frontend/lib/locale_return.ts` (new, the return rule), `app/frontend/lib/locale_return.test.ts` (new), `app/frontend/entrypoints/application.ts` (wiring), `app/views/settings/show.html.erb` (`data-turbo-action="replace"` on the language links), `app/frontend/controllers/previous_screen_controller.ts` (always `history.go`), `app/frontend/lib/history_trail.ts` and its test (`localeChanged` and the dead skip removed, `inLocale` exported).
- Review: 4 patches (1 medium, 3 low), 0 deferred, 3 rejected (no wiring unit test; scroll and focus not restored after a language change; same-tab typed other-language address), reasons in the triage log.
- Follow-up review recommended: false (one medium, no high patched).
- Verification: as below, all passing.
- Residual risks: the restore redirect relies on Turbo setting its restoration index after `turbo:visit` (Turbo 8.0.23); Back after a language change lands at the top of the previous screen.

## Verification

**Commands:**
- `npm run test:js` (472 tests), `npm run typecheck` -- pass
- `bin/ci` (2826 Rails tests, 0 failures), `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- pass

**Manual checks (if no CLI):**
- Headless Chrome: French screen → settings → English → app back and browser Back both show the previous screen in English; with no language change, Back restores the French screen as before.
