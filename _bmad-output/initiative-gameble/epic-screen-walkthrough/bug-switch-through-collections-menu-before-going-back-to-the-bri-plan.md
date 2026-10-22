---
title: 'Switch through collections menu before going back to the bridge'
type: 'bugfix'
ticket: '11'
created: '2026-10-22'
status: 'built'
baseline_revision: '792160528fa061b4f132a7839ab5923b05effb1a'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** From the capsule screen, going back to the bridge briefly shows the collection screen first. The likely cause is a Turbo snapshot of another page stored under the bridge's address and previewed on each visit; how it gets there is unproven (not reproduced).

**Approach:** Defensive guard, decided by the author without a reproduction: on any visit to the bridge (link, Turbo.visit, history back/forward), empty Turbo's snapshot cache first so no foreign page can preview. The original cause remains unproven.

</intent-contract>

## Implementation Notes

Oneshot: about 60 lines. New `app/frontend/lib/bridge_cache.ts` (pure address rule plus the listeners), registered in `app/frontend/entrypoints/application.ts`, `Turbo.cache` typed in `lib/turbo.ts`. Turbo reads its snapshot cache synchronously when a visit starts, before `turbo:visit`, so the guard hooks `turbo:before-visit` and a capture-phase `popstate`. Vitest for the rule; a system test seeds a collection snapshot under the bridge address and asserts the bridge shows without the collection rendering.

## Verification

**Commands:**
- `npm run test:js`, `npx tsc --noEmit`, the new system test and neighbouring navigation system tests, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec i18n-tasks health`

## Review Triage Log

### 2026-10-22 - Review pass
- verdicts: 9 findings - high 0, medium 0, low 3, false 2, maybe-false 0 (4 rejected as low or out of reach)
- findings:
  - `[false]` `[reject]` popstate listener is not capture-phase - a capture listener was tried first and ran after Turbo's own in this Chrome (the first system run restored the foreign page); import order is the working mechanism and the system test guards it.
  - `[low]` `[reject]` clear runs before a cancelled visit is known - harmless extra eviction, a fix adds branches.
  - `[low]` `[reject]` the whole cache is cleared, not one entry - public API only; previews are a speed aid; accepted trade-off.
  - `[low]` `[patch]` two-line comment in bridge_cache.ts - cut to one line.
  - `[low]` `[patch]` class comment in the system test - removed.
  - `[false]` `[reject]` the extra guard file and application.ts comment follow from the import-order mechanism above.
  - `[low]` `[reject]` Turbo.visit and forward are not tested - same Turbo path as a link (before-visit) and as back (popstate).
  - `[false]` `[reject]` "no run without the guard shown" - run: both system tests fail with the guard disabled (the link test sees a previewed library, the history test shows the library under the bridge address).
  - `[low]` `[reject]` query-string and hash cases untested in vitest - pathname-based, query case covered.

## Auto Run Result

- Summary: on a visit to the bridge (link, Turbo.visit, history), Turbo's snapshot cache is emptied first, so no foreign page previews or restores. The original cause remains unproven; this is a preventive guard.
- Files: app/frontend/lib/bridge_cache.ts (rule and listeners), bridge_cache_guard.ts (side-effect import), bridge_cache.test.ts, entrypoints/application.ts, lib/turbo.ts, test/system/bridge_cache_test.rb.
- Review: 2 patches (comments), 7 rejected with reasons above, none deferred.
- Follow-up review recommended: false.
- Verification: vitest 559 pass, tsc clean, new system tests pass and both fail with the guard disabled; hub, shell, collection_set, countdown, library system tests pass; zeitwerk, packwerk, rubocop clean; i18n-tasks missing/unused clean (pre-existing normalization notice).
- Residual risk: the symptom may have another cause; the guard also empties other screens' previews after each bridge visit.
