---
title: 'The packs chip reads the countdown in total minutes (1440:00) for a pack more than an hour away'
type: 'bugfix'
ticket: ''
created: '2026-10-13'
status: 'done'
baseline_revision: 'c0473bc78ea7d9844d0be56b9b652d8811a20a84'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The top bar's packs chip renders its countdown clock as total minutes and seconds (`format("%02d:%02d", *seconds.divmod(60))` in `app/views/shell/_packs_chip.html.erb:22`, mirrored by the Stimulus ticker in `app/frontend/controllers/countdown_controller.ts`), so a pack more than an hour away reads `1440:00` instead of a time in hours.

**Approach:** Render the packs chip clock as `H:MM:SS` from an hour, else `MM:SS` — the countdown format already established by `formatClock` in `app/frontend/lib/booster.ts` — on both the server-rendered clock and the client tick, so they never disagree. The daily booster keeps its always-padded `HH:MM:SS` (ShellHelper#format_clock, the controller's `hours` value) untouched.

</frozen-after-approval>

## Implementation Notes

Oneshot starts here: the change is small (two format sites plus a helper) and the intended format has a tested precedent — `formatClock` in `booster.test.ts` (3600 → "1:00:00", 3599 → "59:59").

Implementation decisions:
- Added `ShellHelper#format_remaining` beside `format_clock`; the packs chip's server-rendered clock now calls it.
- `countdown_controller.ts#show` now calls `formatClock` from `../lib/booster` for the non-`hours` branch (the packs chip), so the client tick reuses the same tested function; the daily booster's `hours` branch is byte-for-byte the same output as before.
- Added `format_remaining` cases to `shell_helper_test.rb` and a > 1 h scenario to `packs_controller_test.rb` (10:00 and 05:00 assertions elsewhere are unaffected).
- Local verification: Ruby is not installed on this machine; the Rails suite (helper + controller tests) and packwerk run in CI. `npm run test:js` ran locally: 224 passing, including `booster.test.ts`'s `formatClock`.

## Plan Change Log

## Review Triage Log

Quick lens `quick` (one pass, three findings):

- medium — the new over-an-hour controller test was wall-clock dependent (`create_pack(available_at: 90.minutes.from_now)` then exact `5400`/`1:30:00` assertions), able to flake in CI under load; `shell_next_pack_in` truncates with `.ceil`. Patched: the test pins time with `travel_to(now)` and asserts the exact `15:52` time, like its siblings.
- medium — the client tick hand-copied the "H:MM:SS from an hour, else MM:SS" rule (duplicating `formatClock`), and no test covered a Stimulus controller's formatting. Patched: `countdown_controller.ts#show` now calls `formatClock` from `../lib/booster` for the packs chip (the daily `hours` branch unchanged, pre-existing), so the client and the island share one tested function. No Stimulus-controller vitest infrastructure exists in the repo; the remaining untested formatting is the pre-existing `hours` branch only.
- low — the added helper and controller comments stated design intent, contrary to the AGENTS.md comment rule. Patched: `format_remaining` keeps a one-line format label matching `format_clock`'s; the controller's per-method comment reverted.

## Verification

**Commands:**
- `bundle exec packwerk check` -- CI only; Ruby is not installed locally. expected: no violations
- `bin/rails test test/helpers/shell_helper_test.rb test/controllers/packs_controller_test.rb test/integration/shell_test.rb` -- CI only. expected: added `format_remaining` cases and the over-an-hour countdown test pass; existing packs chip assertions unchanged
- `npm run test:js` -- ran locally: all 224 tests pass (boosted by `booster.test.ts`'s `formatClock` cases)
- `bin/rails zeitwerk:check` -- CI only. expected: no autoload errors

**Manual checks (if no CLI):**
- None: server-rendered packs chip and Stimulus tick now share one format rule ("H:MM:SS" from an hour, else "MM:SS").