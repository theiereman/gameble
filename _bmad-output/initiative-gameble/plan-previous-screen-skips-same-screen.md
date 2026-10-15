---
title: 'The desktop back button names the previous different screen, not an earlier page of the same one'
type: 'bugfix'
ticket: ''
created: '2026-10-13'
status: 'done'
baseline_revision: '02d86fc4062986e0cba04ada229b0cdc4bbcb196'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      Switching language on the settings screen still shows the desktop back button leading back to the same screen, since same-screen is judged by the translated label.
    evidence: |-
      shell_screen_label returns t("shell.screens.…"), so /en/settings records "Profile" and /fr/settings "Profil"; the LANGUE links are Turbo visits, so the trail is not reset. Pre-existing: the old button showed it too.
    location: >-
      app/frontend/lib/history_trail.ts (previousScreen)
    severity: low
---

<intent-contract>

## Intent

**Problem:** On the collection, changing page or set kind makes the top bar's desktop back button appear ('◀ SETS') although it leads back to the same screen: every URL change records a history-trail entry with the same screen label, and `previous_screen_controller.ts` shows the button whenever the entry right before the current one has a label (bug reported by the author, 2026-10-13).

**Approach:** Per the Back button row of the UX experience document ("returns to the previous screen, like the browser's Back, which comes back as it was left (scroll, filters, page) … Hidden when the previous screen is the hub … or when the tab holds no earlier gameble screen"), the button names and returns to the nearest earlier entry whose screen differs from the current one, skipping entries of the same screen (same screen label), and goes back that many history steps with `history.go(-n)` so the earlier screen is restored as it was left. It is hidden when that nearest different entry is the hub (unlabelled) or unknown. Examples: collection page 3 reached from the hub through pages 1 and 2 → hidden; card detail opened from collection page 2 → '◀ SETS', one step back to page 2; collection page 2 after coming from the card detail → '◀ FICHE', going back past the collection entries. The decision is a pure function in `app/frontend/lib/history_trail.ts` with vitest cases for those examples, the hub stop, an unknown entry and the plain one-step case. The phone contextual back and `history_back_controller.ts` stay unchanged: they go back to the nearest entry with a given pathname, which already lands on the page the detail was opened from.

</intent-contract>

## Implementation Notes

Oneshot: about 60 lines across `history_trail.ts` (a pure `previousScreen(trail, index, currentLabel)` replacing `labelBefore`/`entryBefore`, which only the previous-screen controller used, plus an exported `readTrail`), `previous_screen_controller.ts` and `history_trail.test.ts`.

- The current screen's label is read from the top bar (`currentScreenLabel`), not from the trail: the controller connects before `turbo:load` records the current entry.
- `back` recomputes the step count at click time rather than trusting what `sync` saw, so a frame visit that advanced history since the last sync still goes back the right number of entries.
- Same screen means same label, as the intent says; the screens sharing a label (settings, a friend's profile and a public profile all read "Profile") therefore count as one screen for this button.

## Plan Change Log

- 2026-10-15, after the author's staging review: switching the language in Profil et paramètres pushed /en/settings after /fr/settings, and since « PROFIL » and « PROFILE » differ the button offered « ◀ PROFIL » back to the French page. The previous screen now stops at an entry read in another language (the URL's locale segment), so the button is hidden right after a language change.

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[defer]` A language switch on settings shows '◀ PROFILE' back to the same screen, as labels are translated — real (the LANGUE links are Turbo visits, the trail keeps the other language's label), but pre-existing: the old entry-before rule showed the same button; the fix needs a new language-independent screen key in the HTML and the trail. Recorded in deferred-work.md.
  - `[low]` `[patch]` The new doc comments on `readTrail` and `PreviousScreen` restate their names, against the comment rule — both removed.
  - `[false]` `[reject]` The diff from the baseline includes a tickets.toml hunk — that hunk is commit 8da410f, made by another session after the baseline; the commit stages only this fix's files.

## Auto Run Result

- **Change:** the desktop back button now names and returns to the nearest earlier history entry of another screen, skipping the entries of the current screen (`history.go(-n)`); hidden when that entry is the hub or unknown. The step count is recomputed at click time.
- **Files:** `app/frontend/lib/history_trail.ts` (pure `previousScreen`, exported `readTrail`, `labelBefore`/`entryBefore` removed); `app/frontend/controllers/previous_screen_controller.ts` (uses it, goes back n steps); `app/frontend/lib/history_trail.test.ts` (cases for the three examples, the hub stop, an unknown entry, the plain one-step case, replaced entries, empty labels, broken storage).
- **Review:** 1 low patch applied, 1 low deferred (language switch on settings), 1 false rejected. Follow-up review recommended: false (no high, no medium patched).
- **Verification:** `npm run test:js` 248 passed; `npm run typecheck` clean; `bin/rails test` 2408 runs, 0 failures; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` no offenses. No system tests run.
- **Residual risk:** the browser behaviour is untested by automation (system tests are disabled); check by hand as in Verification.

## Verification

**Commands:**
- `npm run test:js` -- expected: all vitest files pass, including the new `previousScreen` cases
- `npm run typecheck` -- expected: no errors
- `bin/rails test`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: green

**Manual checks (if no CLI):**
- Desktop width: from the hub open the collection, change page twice → no back button; open a card from page 2 → '◀ SETS' (or the collection's label), click → page 2 at its scroll; from the card go to the collection and change page → '◀ FICHE', click → the card detail.
