---
title: 'The countdown and the reserve refresh without reloading the screen'
type: 'feature'
ticket: '5'
created: '2026-11-06'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** When the next-capsule countdown reaches zero on a sealed or empty screen, the booster reloads the whole page (`refreshPage`), which costs a full visit, can land on an error page offline (the app replaces the screen), and drops the held capsules the client already has. A failed bank read is never retried.

**Approach:** At zero, read the bank JSON (bank and held capsules) instead of reloading, and let the state module move from empty to sealed from it. A failed read is retried when the browser fires `online` and when the document becomes visible, with no page visit.

## Boundaries & Constraints

**Always:** Keep the existing owed-bank logic (`atZero` "owe" and `bankDue`) for hands in progress. Whatever the empty screen shows that only the server renders (the next-steps panel under `app/views/boosters/_next_steps*.html.erb`, the daily capsule block) must stay correct when a capsule arrives without a reload: check how `booster_next_steps_controller.ts` and the renderer hide them when the phase leaves `empty`, and fix what is missing. Listeners are removed on disconnect.

**Never:** No `Turbo.visit`/`location.reload` from the booster's countdown any more. No server change.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Zero on empty screen | phase empty, countdown hits zero | bank JSON read; phase sealed; canister shown; held capsule kept; no visit | No error expected |
| Zero on sealed screen | phase sealed | bank JSON read, counts updated, no visit | No error expected |
| Zero mid-hand | phase dealt, hand not put away | owed as today | No error expected |
| Read fails | fetch rejects | screen unchanged; read again on `online` or on becoming visible | no error page, no toast |

</frozen-after-approval>

## Code Map

- `app/frontend/lib/booster_bank_refresh.ts` -- `BankRefresh.atZero` (`"page"` → `refreshPage()`), `refresh()` (returns silently on failure).
- `app/frontend/lib/booster_bank.ts` -- `atZero`, `owedBankDue`, `phaseForBank`, `fetchBank` (story 3 extended it with `held`).
- `app/frontend/lib/booster_state.ts` -- `countdownAtZero`, `bankFetched`.
- `app/frontend/controllers/booster_controller.ts` -- countdown wiring and `visibilitychange` (at 400 lines: wire through the lib collaborator).
- `app/frontend/controllers/booster_next_steps_controller.ts`, `app/views/boosters/_next_steps*.html.erb`, `_daily.html.erb` -- server-rendered empty-state parts.
- Tests: `booster_bank.test.ts`, `booster_state.test.ts`, a new or existing test for `BankRefresh`.

## Tasks & Acceptance

**Execution:**
- [ ] `booster_bank_refresh.ts` / `booster_bank.ts` -- zero reads JSON; retry on online/visible
- [ ] empty-state parts follow the phase without a reload
- [ ] tests for every matrix row

**Acceptance Criteria:**
- Given the empty screen, when a capsule arrives at zero, then the canister appears without any page visit.

## Verification

**Commands:**
- `npm run test:js && npm run typecheck && npm run format:check` -- expected: green
- `script/check_file_sizes && script/check_planning_references` -- expected: clean
