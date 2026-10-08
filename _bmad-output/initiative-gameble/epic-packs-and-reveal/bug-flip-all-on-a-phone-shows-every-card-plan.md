---
title: 'Flip all on a phone shows every card'
type: 'bugfix'
ticket: '11'
created: '2026-10-03'
status: 'built'
baseline_revision: '530566b5df8ddffb9ccbcc1a5364ed411c02f609'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/story-pack-reveal-island-plan.md']
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** On a phone (one large card at a time), "flip all" moves the view only to each gold card and then to the last card; there is no "previous" control and "next" shows only before the last card, so the player never sees the other cards flip all turned. The view changes also unmount the focused card without moving focus, so focus falls to `<body>` (retrospective B1, `app/frontend/components/PackReveal.tsx` `flipAll`/`next`/the next-button condition).

**Approach:** On the phone layout, add a "Previous card" control beside "Next card", so every card can be reached in turn, forward and back, once the run is over (previous whenever `current > 0`, next as today: the shown card flipped and `current < last`; both hidden while flip all runs). Flip all still shows and holds each gold card for its full length, then ends on the first card it turned, so the player steps forward through the newly turned cards with "Next card". Every view change made by flip all, next or previous keeps focus inside the reveal: when the focus was on the card being replaced (or on a nav button that disappears), focus moves to the newly shown card. Wider screens are unchanged. The words "Previous card" / "Carte précédente" are resolved on the server like the other reveal strings (AD-16).

Constraints: keep the current look (the existing secondary button style and nav row, no new visuals); a legendary's reveal is never shortened (EXPERIENCE.md); no change to `reveal.ts` timing or to the desktop layout; no server call during the reveal.

Assumption (open question B1 of the retrospective, recorded in `pending-approvals.md` under the UX redesign): free navigation with previous and next on phone, and flip all ending on the first card it turned rather than the last.

</intent-contract>

## Tasks & Acceptance

- `app/frontend/components/PackReveal.tsx` -- `previous` string; a `showCard(index)` that sets `focusShown` when focus is on the shown card, then `setCurrent`; use it in flip all's steps and end (end on `plan.steps[0].index`); "Previous card" button in the nav row; next/previous always move focus to the new card.
- `app/controllers/packs_controller.rb`, `config/locales/{en,fr}.yml` -- `previous` string.
- `app/frontend/styles/reveal.css` -- the nav row holds both buttons (rename `.pack-reveal__next` to `.pack-reveal__nav`).
- `test/system/pack_reveal_test.rb` -- the phone test: focus on the shown card, flip all (triggered without moving focus), each gold shown and held its full length, the run ends on the first card turned, then every card reached forward to 5 / 5 and back to 1 / 5, each face up, focus inside the reveal at every step.
- `test/controllers/packs_controller_test.rb` -- the `previous` prop in English and French.
- `_bmad-output/initiative-gameble/pending-approvals.md` -- the B1 assumption.

**Acceptance:** Given a signed-in player on a 390 × 844 window who opens a pack with two gold cards, when they flip all, then each gold card is shown face up and held its full length, the view ends on the first card flip all turned, "Previous card" and "Next card" reach each of the five cards in turn, face up, and focus never leaves the reveal.

## Implementation Notes

Oneshot: about 70 lines across one component, its strings, a CSS rename and two tests.

- `PackReveal.tsx`: `showCard(index)` (used by flip all only) does nothing when the view is already on that card, and asks the focus effect to move focus only when focus was inside the card list, so a focus on "Flip all" stays there. `currentRef` mirrors `current` for flip all's timers. "Next card" and "Previous card" always move focus to the new card, as "next" did; the phone focus block was moved above flip all so `showCard` is declared before use.
- `reveal.css`: `.pack-reveal__next` renamed `.pack-reveal__nav`, no visual change.
- System test: flip all is triggered with a script click so the focus stays on the shown card, as a tap on Safari leaves it; with the `showCard` focus line removed, the test fails (checked), so it covers the focus loss. Gold hold measured between the two golds' `data-flipped-at`, each read while shown.
- Verification: targeted tests 29 runs green; `bin/rails test` 857 runs, `bin/rails test:system` 43 runs, all green (test database); typecheck, Vitest 60, rubocop, i18n-tasks, packwerk clean.

## Plan Change Log

## Review Triage Log

### 2026-10-03 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 2, false 0, maybe-false 1
- findings:
  - `[low]` `[reject]` Focus on "Previous card" or "Next card" is lost when flip all starts, since the nav row unmounts while running and `showCard` only follows a focused card — real but unlikely: a mouse click or key press on "Flip all" focuses it, and a tap on next or previous leaves focus on the new card (moved there programmatically), so focus sits on a nav button only through assistive technology that activates without focusing; the fix adds a branch for a state not shown reachable in everyday use.
  - `[low]` `[patch]` The test measured the first gold against the second gold (gap includes the emerald's 150 ms stagger) and never the second gold — patched: `flipped_at` and `reveal_ms` are read for each card during the forward walk, and each gold (2 and 4) is checked against the very next card (`flippedAt(next) − flippedAt(gold) ≥ gold length`).
  - `[medium]` `[patch]` Two one-shot `document.activeElement` checks after timer-driven view changes can race the focus effect and flake — patched: `assert_focus` retries through `page.document.synchronize`; used after every view change in the test.
  - `[maybe-false]` `[reject]` The no-sideways-scroll check never sees both nav buttons at 390 px — would only be low if true: the nav row keeps `flex-wrap: wrap` and the existing secondary buttons; settled by a scroll check at 3 / 5 in French.

## Verification

**Commands:**
- `bin/rails test test/controllers/packs_controller_test.rb test/system/pack_reveal_test.rb` -- expected: green.
- `bin/rails test && bin/rails test:system` -- expected: green.
- `npm run typecheck && npm run test:js && bin/rubocop && bundle exec i18n-tasks missing` -- expected: no offence.

## Auto Run Result

- **Change:** on a phone, the reveal gains "Previous card" beside "Next card"; flip all still shows and holds each gold card, then returns the view to the first card it turned; every view change made by flip all moves focus to the new card when the replaced card had it, so focus never falls to the body.
- **Files:**
  - `app/frontend/components/PackReveal.tsx` -- previous control, `showCard` for flip all's view changes with focus kept, end on the first card turned.
  - `app/controllers/packs_controller.rb`, `config/locales/{en,fr}.yml` -- the `previous` string.
  - `app/frontend/styles/reveal.css` -- `.pack-reveal__next` renamed `.pack-reveal__nav`.
  - `test/system/pack_reveal_test.rb` -- phone test: flip all with focus on the card, golds held, every card forward and back, focus in the reveal.
  - `test/controllers/packs_controller_test.rb` -- the `previous` prop in both languages.
  - `_bmad-output/initiative-gameble/pending-approvals.md` -- the B1 assumption (separate docs commit).
- **Review (quick):** 2 patches (1 medium, 1 low, both in the test); 0 deferred; 2 rejected (focus on a nav button when flip all starts: unlikely, added branch; two nav buttons at 390 px: maybe-false, low at most).
- **Follow-up review recommended:** false (one medium patched, no high).
- **Verification:** targeted 29 runs green; `bin/rails test` 857 runs, `bin/rails test:system` 43 runs, green on the test database; typecheck, Vitest 60, rubocop, i18n-tasks, packwerk clean. Removing the focus line in `showCard` makes the phone test fail (checked before the patch).
- **Residual risks:** the touch path on a real phone (Safari) is not run; the French nav row at 390 px is not asserted.
