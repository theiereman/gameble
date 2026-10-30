---
title: "Back after a language change keeps the previous screen's scroll, and only a language chosen in the settings carries over"
type: 'bugfix'
ticket: 'bug-back-after-a-language-change-keeps-the-scroll-and-only-a-settings-choice-carries'
created: '2026-10-19'
status: done
baseline_revision: 'ac80a01a6e3a085a6db0c78ac87e610b8a280f51'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/backlog/bug-back-from-settings-restores-the-previous-language-plan.md'
warnings: []
deferred:
  - summary: >-
      The settings view's header comment still cites EXPERIENCE.md and DESIGN.md, which the repo policy forbids in code.
    evidence: |-
      app/views/settings/show.html.erb:9-10 reads "(EXPERIENCE.md, Settings row; DESIGN.md, Profile and settings)"; the citations predate this change, which leaves the comment block as it was.
    location: >-
      app/views/settings/show.html.erb:9
    severity: low
---

<intent-contract>

## Intent

**Problem:** Since the first fix of #52, a return through history to an entry read in another language than the one shown last is turned into a fresh replace visit of that address in the shown language: the previous screen opens at the top, without its scroll position or its return focus. And the language "shown last" is whatever page the tab read last, so a page opened in the other language by a link or a pasted URL switches the language of the earlier entries too.

**Approach:** Only a language chosen with the settings language links is remembered as the tab's choice, together with the addresses shown since that choice. A return through history to an address in another language than the choice, not shown since the choice, is rewritten in place: the entry's URL is replaced in the chosen language and Turbo restores that same entry (its restoration identifier, so its scroll position, and a restore action, so the return focus), fetching the page in the chosen language. With no choice made in the tab, or for an address shown since the choice, back is a plain back. Back without a language change is unchanged.

</intent-contract>

## Implementation Notes

Oneshot: about 100 lines in `app/frontend/lib/locale_return.ts` and its vitest, one data attribute on the settings language links, and the restore options in the `window.Turbo` type.

- Code: `app/frontend/lib/locale_return.ts` (the rule, wired from `app/frontend/entrypoints/application.ts`), `app/views/settings/show.html.erb` (the language links), `app/frontend/lib/turbo.ts` (the typed `window.Turbo`), `app/frontend/controllers/history_back_controller.ts` (focuses the return link on a `restore` visit; must keep working untouched).
- Turbo 8.0.23: a restore visit scrolls to the position Turbo recorded for the entry's restoration identifier (`Visit#scrollToRestoredPosition`), falling back to the top.
- Built: `locale_return.ts` keeps `{ locale, shownSince }` in sessionStorage (`gameble:locale-choice`): a `turbo:click` on a link marked `data-locale-choice` (the settings language links) starts it afresh; every page shown in another language than the choice adds its path and query (the latest 100). A return through history (Turbo restore, back/forward document load, back/forward-cache restore) to an address in another language than the choice, not read since it, rewrites the current entry's URL in the chosen language (`history.replaceState`, same Turbo state) and dispatches a `popstate` for it: Turbo restores that same entry, so its scroll position, and `history_back_controller.ts` focuses the return link as on any restore visit. No choice in the tab: back is plain. The old `gameble:shown-locale` key is no longer read.
- Chose a synthetic `popstate` over `Turbo.visit` with undocumented `restorationIdentifier`/`historyChanged` options: it goes through Turbo's own Back path and keeps Turbo's notion of the current location in step with the rewritten URL.
- Surprise: a cached snapshot restored across languages (an English link opened in a French tab, then Back) kept `<html lang="en">` over the French page, as before either fix; `turbo:render` now sets `lang` from the address's locale.
- Limit: the pages read since the choice are matched by path and query, so the same address read in the other language both before and after the choice keeps that language on Back.
- Headless Chrome (desktop 1280x500, dev seeds, a player holding cards), before → after: French collection scrolled to 337, settings, English, app back: `/en/library` at 0 → at 337; same with browser Back → at 337; all cards grid scrolled to 1114 → card → settings → English → Back, Back: grid in English at 0, nothing focused → at 1114 with the card's link focused; an English link (and a pasted English URL) opened from the French collection, then Back: `/en/library` → `/fr/library` in French at 337 (`lang="fr"`); no language change: unchanged (337); settings → English → pasted French page → French page → Back, Back, Back: French page kept in French at its scroll, `/en/settings`, then `/en/library` at 337 (at 0 with the back/forward cache off, as a plain Back across a full page load also lands at 0).
- The `window.Turbo` type was not touched after all: the synthetic `popstate` needs no new Turbo option.
- Review patch: the phone's contextual back ("◀ Grille", `history_back_controller.ts`) found no earlier entry once the card page was rewritten in English (the grid's entry still held the French path), so it made a plain visit at the top. `stepsBackTo` (`app/frontend/lib/history_trail.ts`) now matches an earlier entry showing the same path in the other language; going back to it, `locale_return.ts` rewrites it in the chosen language. `ROUTED_LOCALES` and `routedLocaleOf` moved to `history_trail.ts` for that.
- Headless Chrome, phone 390x700, after the patch: all cards grid scrolled to 3746 → card → settings → English → Back (card in English) → ◀ Grille: `/en/library/cards` at 3746 with the card's link focused, as without a language change (`/fr/library/cards` at 3746, link focused). Desktop scenarios re-run after the patch: unchanged.

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `medium` `patch` The phone's "◀ Grille" back after a language change made a plain visit at the top without focus: `stepsBackTo` compared pathnames exactly and the grid's trail entry kept its French path — `stepsBackTo` now matches the same path in either routed language; verified in headless Chrome at phone width (scroll and focus kept) and by a new vitest case.
  - `low` `patch` The docstrings on `rememberShownPage` and `SHOWN_SINCE_LIMIT` narrate intent — removed; the `restoreEntryAt` comment now states the Turbo constraint it relies on (scroll restored only on a restore visit started by popstate).
  - `low` `patch` The added phrase in the settings view's comment narrates intent — removed.
  - `low` `defer` The settings view's comment still cites EXPERIENCE.md and DESIGN.md — pre-existing, not caused by this change; deferred.
  - `low` `reject` The `turbo:click` → choice, `replaceState` + `popstate` and `turbo:render` wiring has no automated test — vitest runs in node and system tests are disabled; a DOM and Turbo harness would add more than it checks. Covered by the headless Chrome runs; the view test asserts the links carry `data-locale-choice`.
  - `low` `patch` `package-lock.json` rewritten by `npm install` in the worktree — reverted, not committed.

## Auto Run Result

- Summary: only a language chosen with the settings language links is remembered (per tab, with the pages read in the other language since); a return through history to a page read before the choice, in the other language, rewrites that same history entry's URL and lets Turbo restore it, so it opens in the chosen language at its scroll position with the return focus; with no choice, or for a page read since the choice, Back is plain. A snapshot restored across languages now gets the right `<html lang>`. The phone's contextual back finds the previous screen across languages.
- Files: `app/frontend/lib/locale_return.ts` (the choice and the in-place restore), `app/frontend/lib/locale_return.test.ts`, `app/frontend/lib/history_trail.ts` (`stepsBackTo` across languages; `ROUTED_LOCALES`, `routedLocaleOf` moved here), `app/frontend/lib/history_trail.test.ts`, `app/views/settings/show.html.erb` (`data-locale-choice` on the language links), `test/controllers/settings_controller_test.rb`.
- Review: 4 patches (1 medium, 3 low), 1 deferred (pre-existing planning citations in the settings view comment), 1 rejected (no wiring test: node vitest, system tests disabled).
- Follow-up review recommended: false (one medium patched, no high).
- Verification: as below, all passing.
- Residual risks: the in-place restore relies on Turbo 8.0.23 handling a dispatched `popstate` as a Back to the current entry (`History#onPopState`) and on its restoration index moving after `turbo:visit`; a page read in the other language both before and after the choice keeps that language on Back (matched by path and query); a Back across a full page load without the back/forward cache lands at the top, as a plain Back does.

## Verification

**Commands:**
- `npm run test:js`, `npm run typecheck` -- pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- pass

Results: `npm run test:js` 480 tests pass, `npm run typecheck` pass, `bin/ci` 2831 Rails tests 0 failures (a first run hit one transient Vite manifest error in an unrelated test, which passed alone and on the rerun), zeitwerk and packwerk pass.

**Manual checks (if no CLI):**
- Headless Chrome: from a French screen scrolled halfway, settings → English → the app's back, then again with the browser's Back: the screen opens in English at the same scroll position; an English link opened in a French tab, then Back: the French page in French; back without a language change unchanged.
