---
title: 'Booster and shell split'
type: 'refactor'
ticket: '15'
created: '2026-10-08'
status: 'in-progress'
baseline_revision: 'df6e36dc6e6290439e566939e6aac4eee4a4a2a7'
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `Booster.tsx` (1,616 lines) holds the island's state and protocol, every keyframe list, the DOM effects, the timers, the lock, the live region, the countdown and the banner in one function; `booster.css` (1,564) and `shell.css` (1,262) grew the same way (retrospective F2, action item 1).

**Approach:** Move code out of `Booster.tsx` by reason to change (motion, effects, lifetime hooks, browser helpers, types, banner), leaving it the island's state, protocol and view; cut `booster.css` in two at a section boundary; keep `shell.css` whole and record why. No behaviour, markup or compiled-CSS change.

## Boundaries & Constraints

**Always:** code moved verbatim except the signature changes the move needs (an element, `wait` or callback passed in); the rendered markup and the built CSS are identical to the baseline; `import type { BoosterProps } from "../components/Booster"` keeps working; comments naming a moved rule or function point to its new file; new files follow the neighbours' naming (`lib/snake_case.ts`, `components/useX.ts`, `components/BoosterX.tsx`) and comment density.

**Never:** no behaviour, timing, keyframe value, class name, string or prop change; no change to `lib/booster.ts`'s exports, `BoosterCard`/`BoosterCanister`/`BoosterPanel`/`BoosterStrip`/`BoosterPlate`/`BoosterTray`/`BoosterZoom`/`useCardSwipe`, the card face or its baselines; no test weakened or deleted (added only); no `@media` block split or rule reordered.

</frozen-after-approval>

## Code Map

- `app/frontend/components/Booster.tsx` -- sections: types 128–219; browser helpers `newKey`, `csrfToken`, `visit`, `refreshPage`, `readLayout` 226–261; `useCountdown` 269–300; state 306–373; timers/dispose 399–436; lock 438–453; live region 455–462; focus 464–498; effects `animate`, `settle`, `stageShake`, `stageFlash`, `spark`, `ring`, `burst`, `blast` 500–594; banner 596–621 and markup 1559–1578; opening 631–819 (inline keyframes in `retract`, `blowAndDeal`, `fadeAndDeal`, `open`); reveal 821–1059 (`revealTier`, `revealLegendary`, `revealStill`); phone 1061–1215 (`traySparks`, `store`, `springBack`); layout 1217–1261; refresh-at-zero 1291–1309; render 1311–1615.
- `app/frontend/lib/booster.ts` -- constants and pure helpers (`pose`, `scaled`, `shakeKeyframes`, `dealKeyframes`, `burstPixels`…); read only, reused by the new modules.
- `app/frontend/entrypoints/application.ts:10,26` -- imports `BoosterProps` type and lazy-loads the default export.
- `app/frontend/entrypoints/application.css:14` -- `@import "../styles/booster.css"`, last import.
- `app/frontend/styles/booster.css` -- 1–973 the island at its base (layout, panel, stage, canister, cards, effects, banner, loops); 974–1564 the narrower panels, the narrow row, the phone, the zoom and reduced motion (no `@media` crosses 973/974).
- `app/frontend/styles/shell.css` -- the phone (1070–1196) and reduced-motion (1197–1257) blocks each style the top bar, tab bar, toasts, buttons and modal together.
- `test/system/booster_test.rb`, `test/system/card_face_visual_test.rb`, `app/frontend/lib/booster.test.ts` -- the gates.

## Tasks & Acceptance

**Execution:**
- [ ] `app/frontend/lib/booster_props.ts` -- `BoosterStrings`, `BoosterBank`, `BoosterProps`, and `Status` exported as `BoosterStatus`; `Booster.tsx` re-exports the three public types.
- [ ] `app/frontend/lib/booster_page.ts` + `booster_page.test.ts` -- `newKey`, `csrfToken`, `visit`, `refreshPage`, `readLayout`; test `newKey`'s fallback gives a v4 UUID shape.
- [ ] `app/frontend/components/useBoosterCountdown.ts` -- `useCountdown` and `useRefreshAtZero(left, canRefresh)` holding the refresh-at-zero effect and `REFRESH_AFTER_ZERO`.
- [ ] `app/frontend/components/useIslandTimers.ts` -- `disposed`, `wait`, `later` and the unmount clearing; `components/useNavigationLock.ts` -- `locked`, depth, `lock`, `unlock(onReleased)`, the release on unmount; `components/useLiveRegion.ts` -- `announcements`, `announce`, `ANNOUNCEMENTS_KEPT`.
- [ ] `app/frontend/lib/booster_effects.ts` -- `animate`, `settle`, `spark`, `ring`, `stageShake`, `stageFlash`, and `burst`, `blast`, `traySparks` taking their host and target elements; no React.
- [ ] `app/frontend/lib/booster_keyframes.ts` + `booster_keyframes.test.ts` -- every inline keyframe list of the island (arm, caps, body, dock, sink, tremble, lift, flip, settle, legendary jump/spin/impact/drop, store, slot pop, spring back, banner) as pure functions of their inputs; tests pin first and last frames of a few.
- [ ] `app/frontend/components/BoosterBanner.tsx` -- the banner markup and its layout effect; the island keeps the `banner` state and clears it through a callback.
- [ ] `app/frontend/components/Booster.tsx` -- keeps state, the opening/reveal/store/layout/focus protocol and the render, calling the modules above.
- [ ] `app/frontend/styles/booster.css`, new `app/frontend/styles/booster-layouts.css`, `entrypoints/application.css` -- lines 974–end move to `booster-layouts.css` with its own header, imported right after `booster.css`.
- [ ] `app/frontend/styles/shell.css` -- header line: kept whole, why (Design Notes).

**Acceptance Criteria:**
- Given the baseline and the split, when both are built, then the emitted application CSS is byte-identical.
- Given the booster screen at wide, narrow and phone widths, when a pack is opened and revealed, then `test/system/booster_test.rb` passes unchanged.
- Given the split, when `wc -l` runs, then `Booster.tsx` is under 900 lines and every new module holds one concern named in its header comment.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

The cut is motion vs. state vs. view. Sequences that interleave state and motion (`blowAndDeal`, `revealLegendary`, `store`) stay in `Booster.tsx` as scripts; only their keyframes and effects move, e.g. `animate(lift, trembleKeyframes(level, height, swell), { duration: TREMBLE_MS[level], fill: "forwards" })`. Keyframe builders take `swell` as a function so the phone damping stays in the island.

`shell.css` stays whole: its phone and reduced-motion `@media` blocks each mix top bar, tab bar, toasts, buttons and modal rules; moving the primitives out would split those blocks or reorder rules and change the compiled CSS, which this ticket forbids.

## Verification

**Commands:**
- `bin/vite build` at the baseline and after, then `cmp` the two application CSS assets -- expected: identical
- `npm run typecheck`, `npx vitest run` -- expected: pass
- `bin/rubocop`, `bundle exec packwerk check` -- expected: pass
- `PARALLEL_WORKERS=1 bin/rails test test/system/booster_test.rb test/system/card_face_visual_test.rb test/system/shell_test.rb` -- expected: pass, no baseline regenerated
