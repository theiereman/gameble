---
title: 'A card glare fades where it is when the pointer leaves, instead of sliding back to the centre'
type: 'bugfix'
ticket: ''
created: '2026-10-13'
status: 'built'
baseline_revision: '9dd2e8bcb042fa32c78cce117b0bd4cd6ed10383'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Reported by the author on 2026-10-13 from the real app: when the pointer leaves a tilting card, the glare (`.card__glare` in `app/frontend/styles/card.css`) slides back to the centre of the card while its 200 ms opacity fade runs. It should fade away where it is, just as it appears in place under the pointer when the hover starts (`placeGlareUnderPointer`). In `app/frontend/lib/tilt.ts`, `release()` sets `target = REST`, whose `glareDx`/`glareDy` are 0, so the easing moves the glare to the centre during the fade. Then `clear()` removes `--glare-dx`/`--glare-dy` once the tilt settles, and that can recentre a glare that is still fading.

**Approach:** On release only the tilt (`rx`, `ry`) eases back to rest. The glare's target becomes its current offset, so it stays put for the whole fade. With no pointer driving the card, settling and the rest check look at the tilt alone, not the glare. When the face settles, the glare's custom properties stay as they are. The next drive places the glare under the pointer at once anyway, and detach still removes everything. Touch hold, reduced motion and the booster's use of tilt (the same `attachTilt` through the tilt controller) stay unchanged.

</intent-contract>

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/tilt.ts` -- on release, target rest for the tilt and the current offset for the glare. When no pointer drives the card, settle on the tilt alone and leave the glare's custom properties in place. Detach still removes them all. Update the header comment to match.
- [ ] `app/frontend/lib/tilt.test.ts` -- add a test: after a pointer leaves, the glare offset that is written never moves toward 0 while the tilt eases back, the tilt reaches rest, `data-tilt` and `data-tilting` are cleared, and the next hover places the glare under the new pointer at once. Adapt the assertion that pinned the old clearing of every property at rest.

**Acceptance Criteria:**
- Given a card tilted under a mouse with its glare off-centre, when the pointer leaves, then every frame writes the same glare offset while `--tilt-rx`/`--tilt-ry` ease to 0. Once settled, the tilt properties, `data-tilt` and `data-tilting` are gone and the glare offset is unchanged.
- Given that settled card, when the pointer enters again elsewhere, then the glare is written under the new pointer before any frame runs.
- Given a finger hold, reduced motion or a detach, then the behaviour is as before: detach and reduced motion leave no custom property.

## Implementation Notes

Oneshot: the fix is a few lines in one module plus its unit tests.

- `app/frontend/lib/tilt.ts`: `release()` now aims at `{ ...REST, glareDx: current.glareDx, glareDy: current.glareDy }`, so easing moves only `rx`/`ry`. `step()` settles as soon as the face is still with no driver, so it no longer waits for the glare to reach 0. At that point `settleAtRest()` removes `--tilt-rx`/`--tilt-ry`, `data-tilt` and `data-tilting` and leaves `--glare-dx`/`--glare-dy` as they are. `clear()` (detach) still removes all four. `PROPERTIES` is split into `TILT_PROPERTIES` and `GLARE_PROPERTIES`, and the header comment says what now stays at rest.
- The glare offset left on a resting face does nothing visible, because the glare's opacity is 0 without `data-tilting`. The next drive overwrites it in the same handler that sets `data-tilting` (`drive` then `aim` then `placeGlareUnderPointer`). The tilt controller's disconnect `reset()` still strips all four properties and an emptied `style`, so Turbo snapshots are unaffected.
- Tests: a new test, "fades the glare out where it is while the tilt eases back to rest", leaves the card while the glare is still easing between two pointer positions. It checks that every frame writes the same glare offset while `|rx|` strictly decreases, that the tilt properties and marks are gone at rest, and that the next hover places the glare under the pointer before any frame runs. Adapted: "follows a mouse, holds once settled, and lets go at rest" asserted `card.properties.size === 0` at rest (the old recentring and clearing). It now expects only the glare offset (`-40px`/`-60px`) to remain. Both tests fail on the baseline code and pass with the fix. The touch, reduced motion and detach tests are unchanged and pass.

## Plan Change Log

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 0, maybe-false 0, plus 1 rejected because fixing it means editing the plan
- findings:
  - `[low]` `[reject]` A face hovered before the motion setting turns to reduced keeps `--glare-dx`/`--glare-dy` inline until its next hover or reconnect, while the acceptance criterion reads "reduced motion leaves no custom property". This is true, but nothing shows: reduced motion hides `.card__glare` (`display: none`), and the criterion's scenario, reduced motion when a pointer starts, still leaves none (its test passes). Clearing it would add a motion watcher to the tilt for an invisible inline value.
  - `[low]` `[patch]` The new test checked that only `|rx|` decreases every frame, so a regression that held or snapped `ry` during the fade would pass. Patched: the loop now asserts that both `|--tilt-rx|` and `|--tilt-ry|` strictly decrease every frame.
  - `[low]` `[reject]` The plan's Execution checkboxes are still unticked. Rejected: the fix edits this build's plan, and the Implementation Notes record what was done.

## Verification

**Commands:**
- `npm run test:js` -- expected: all pass, including the new tilt test
- `npm run typecheck` -- expected: no errors
- `bin/rails test`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop` -- expected: green (no Ruby change)

**Manual checks (if no CLI):**
- Hover a card in the library and move the pointer to a corner, then leave the card: the glare fades out where it was while the card tilts back flat, and it never slides to the centre.

## Auto Run Result

**Summary:** When the pointer or finger lets go of a tilting card, only the tilt eases back to rest. The glare keeps its last offset, so it fades out where it was instead of sliding to the centre. Once the tilt settles, the tilt properties and the `data-tilt`/`data-tilting` marks are removed and the glare offset stays, invisible, until the next pointer places it again. Detach and the tilt controller's reset still remove everything.

**Files changed:**
- `app/frontend/lib/tilt.ts`: release aims the glare at its current offset. With no driver, settling ignores the glare, and `settleAtRest()` keeps the glare properties while detach clears them all.
- `app/frontend/lib/tilt.test.ts`: a new test covers the fade in place, the tilt reaching rest with its marks cleared, and the next hover placing the glare at once. One assertion that pinned the old clearing was adapted.
- `_bmad-output/initiative-gameble/plan-glare-fades-in-place.md`: this plan.

**Review:** quick lens, 3 findings. Patched 1 low (the test now checks both tilt axes every frame). Deferred none. Rejected 2: the leftover glare offset after a live switch to reduced motion is invisible (`display: none`), and the plan-checkbox finding would edit this plan.

**Follow-up review recommended:** false. Patched: high 0, medium 0, low 1.

**Verification:** `npm run test:js`: 26 files and 249 tests pass, after the patch too. `npm run typecheck`: clean. `bin/rails test`: 2408 runs, 0 failures. `bin/rails zeitwerk:check`: all good. `bundle exec packwerk check`: no offenses. `bin/rubocop`: no offenses. The new test and the adapted one fail on the baseline `tilt.ts`.

**Residual risks:** A resting card that was hovered now carries an inline `style` with the two glare offsets until the next hover or a reconnect. It has no visual effect.
