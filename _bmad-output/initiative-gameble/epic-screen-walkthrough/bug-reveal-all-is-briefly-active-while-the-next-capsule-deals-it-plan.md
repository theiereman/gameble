---
title: 'REVEAL ALL is briefly active while the next capsule deals its cards'
type: 'bugfix'
ticket: 21
created: '2026-10-24'
status: 'built'
baseline_revision: '8dcacbf74d26517c0b7a5f4eb95dbb3ea42e003f'
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
      "Open the next one" is disabled for the dock's 260 ms before the opening marks it busy, on the button that holds focus.
    evidence: |-
      `openDisabled = ... || (phase === "dealt" && !everyRevealed)` with `total === 0` while the new canister docks after retract().
    location: >-
      app/frontend/components/BoosterView.tsx
    severity: medium
---

<intent-contract>

## Intent

**Problem:** On "Open the next one", `open()` in `app/frontend/components/Booster.tsx` awaits `retract()` while the phase is still `dealt`. Once the old cards have sunk, `retract()` clears the hand (`answer` null, `revealed` empty) and waits for the new canister to dock before the phase turns to `opening`. In that window `revealAllDisabled` in `app/frontend/components/BoosterView.tsx` (`phase !== "dealt" || everyRevealed || …`) is false, because `everyRevealed` needs at least one card, so REVEAL ALL turns on for the dock's 260 ms, then greys out again until the deal. Pressing it then does nothing (`revealAll` returns without an answer), but the button looks usable.

**Approach:** In the view, REVEAL ALL needs a hand on the table: the phase `dealt` *and* at least one card. Name that condition once and use it for REVEAL ALL as well as the hint and the phone's pile top, which already test `phase === "dealt" && total > 0`. A bug fix in place: no change to the island's protocol, the phase machine or any other control. A system test with motion records every moment REVEAL ALL turns on from the request onwards and asserts it happens once, with the new capsule's five cards dealt face down.

</intent-contract>

## Implementation Notes

Oneshot: one condition in the view (a few lines) and one system test, under 100 lines in two files.

- `app/frontend/components/BoosterView.tsx`: `handOnTable` (`phase === "dealt" && total > 0`) gates REVEAL ALL, the phone's pile top and the hint; the island (`Booster.tsx`) is unchanged.
- `test/system/booster_test.rb`: a "with motion" test records, through a MutationObserver installed before "Open the next one", the face-down dealt cards each time REVEAL ALL turns enabled. Before the fix it read `[0, 5]` (enabled during the dock with no card, then at the deal); after it, `[5]`. The log is read only once the state reads INVENTORY: an earlier read caught the flash alone.
- Not changed, seen on the way: in the same dock window "Open the next one" turns disabled (`phase === "dealt" && !everyRevealed` with no card) before the opening marks it busy; outside this ticket.
- System tests ran on the container's Chromium 141 with a matching chromedriver 141, as CI's Chrome was not available here.

## Plan Change Log

## Review Triage Log

### 2026-10-24 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 0, false 1, maybe-false 0
- findings:
  - `[medium]` `defer` In the same dock window "Open the next one" turns `disabled` before the opening marks it busy, on the button that holds focus (`openDisabled` in `BoosterView.tsx`, with `total === 0`) — not this ticket's REVEAL ALL defect; recorded in `deferred` so it is not lost when the plan closes.
  - `[false]` `reject` The plan's status contradicts its Auto Run Result — a bookkeeping state between the halted run and this review; finalization rewrites both.

## Verification

**Commands:**
- `bin/rails test test/system/booster_test.rb` -- expected: the new test fails before the fix (REVEAL ALL turns on with no card dealt) and passes after; the rest of the file passes.
- `npm run test:js` -- expected: pass.
- `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/ci` -- expected: pass.

## Auto Run Result

Status: built

- Summary: REVEAL ALL is enabled only with a hand on the table (`handOnTable`: the phase `dealt` and at least one card), so it stays disabled while "Open the next one" sinks the old cards and docks the new canister.
- Files: `app/frontend/components/BoosterView.tsx` (the condition, shared with the hint and the phone's pile top); `test/system/booster_test.rb` (a with-motion test logging every moment REVEAL ALL turns enabled).
- Review: the Quick lens ran from the coordinating session after the unattended run halted on `no subagents`. 2 findings: 1 deferred (medium, "Open the next one" disabled in the dock window), 1 rejected (false); no patch.
- Follow-up review recommended: false.
- Verification (unattended run): `bin/rails test test/system/booster_test.rb` 40 runs, 0 failures, the new test red before the fix and green three times after; vitest 561, typecheck, `bin/rails test` 3169 runs, rubocop, packwerk, i18n-tasks, zeitwerk, brakeman clean.
- Residual risks: the deferred dock-window disable of "Open the next one".
