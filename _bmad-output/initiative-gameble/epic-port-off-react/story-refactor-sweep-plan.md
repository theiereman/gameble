---
title: 'Refactor sweep'
type: 'refactor'
ticket: 'story-refactor-sweep'
created: '2026-10-27'
status: 'built'
baseline_revision: '692e495d66cc2a6ab3d208f73cb8515bb1c3dbb1'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred:
  - summary: >-
      No test ties the swap burst's class names created in the board controller to the stylesheet selectors.
    evidence: |-
      System tests only play the swap; none asserts .trade-board__ring or .trade-board__confetti exists or is animated.
    location: >-
      app/frontend/controllers/trade_board_controller.ts burst()
    severity: low
---

<intent-contract>

## Intent

**Problem:** The epic's whole-epic review (review-before-the-refactor-sweep.md, same folder) found copies, a dead function, inconsistent naming and untested paths left by the ports of the trade board and the booster.

**Approach:** Apply the review's Do list as cleanup only: shared Ruby and TypeScript helpers replace the copies, each keeping its copies' behaviour byte for byte; add the missing tests. No visible, audible or timing change.

## Boundaries & Constraints

**Always:** Read review-before-the-refactor-sweep.md fully first (findings, Do and Leave lists). Classes, `data-*`, labels, announcements, focus order, keyframes and the opening exchange JSON stay as they are, except the internal `trade-swap__*` to `trade-board__*` class and `trade-swap-*` keyframe renames (CSS, controller and tests together; no test or view may still read the old names). A shared helper keeps each call site on its current variant (`cloneTemplate` drops whitespace nodes). No planning ids in code. Keep tests and typecheck green after each group. Add no dependency. Work only in the worktree on `epic/port-off-react`; do not commit (the parent commits).

**Never:** Change the lock-on-throw or "Reveal all during a Légendaire's hold" behaviour. Edit `test/system/booster_test.rb` beyond the "island" wording (comment near line 45, test name near line 655). Rename the `trade-board--editing`/`--swapping` classes, the `trades.*`/`trade_board.*` locale layout, transition naming. Split files for size. Touch comments outside files and methods this epic created. Run two test commands at once, or run `bin/rails test` without `DATABASE_URL`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Shared helper | each former copy's call | same result as the copy | none |
| Trade board readers | card/number markup in lib | covered by a Vitest file | none |
| French zero | `hint_remaining`, `hint_done`, `summary`, `canister_facts` with count 0 | text identical to `one` | none |

</intent-contract>

## Code Map

- `_bmad-output/initiative-gameble/epic-port-off-react/review-before-the-refactor-sweep.md` -- findings 1-20 with locations; the Do and Leave lists
- `packs/*/app/helpers` or `app/helpers/trades_helper.rb`, `boosters_helper.rb`, `packs_helper.rb`, `app/controllers/boosters_controller.rb` -- findings 1, 15, 16
- `app/frontend/lib/booster_timers.ts`, `booster_templates.ts`, `booster_markup.ts`, `celebration.ts`, `stepper.ts`, `trade_board.ts`, `trade_board_faces.ts` -- shared helpers, findings 3-9
- `app/frontend/controllers/booster_*_controller.ts`, `trade_board*_controller.ts` -- call sites
- `app/assets/stylesheets/**/trades.css` -- finding 13
- `test/controllers/trades_controller_test.rb`, `boosters_controller_test.rb`, `test/system/*` -- findings 2, plus new system tests

## Tasks & Acceptance

**Execution:**
- [ ] Finding 1: one Ruby helper for a rich screen's root data (action routes, outlet selectors, strings), used by TradesHelper and BoostersHelper; unify naming
- [ ] Finding 2: `trades_controller_test.rb` gains the booster-style checks of every action route, outlet selector and `[style]` absence
- [ ] Findings 3, 4, 5, 6: `lib/screen_timers.ts` (from booster_timers, used by the board instead of its `later()`), `lib/templates.ts`, text/data/flag writers, shared `opensElsewhere`, one tier list, one `Fragments` type, one `Intent<Detail>`; each with tests; remove superseded modules and tests
- [ ] Finding 7: the board's `cardFrom`/`number` readers move to lib with a Vitest test
- [ ] Finding 8: `stepperKey` moves into `lib/stepper.ts`
- [ ] Finding 9: delete `nextResult` and its test
- [ ] Finding 10: one `cancelable` rule for all intents
- [ ] Finding 12: send child `reflect` becomes `render`
- [ ] Finding 13: `trade-swap__*`/`trade-swap-*` become `trade-board__*`/`trade-board-*` in CSS, controller and tests
- [ ] Finding 15: strip name-restating comments in files and methods this epic created
- [ ] Finding 17: French `zero` forms equal to `one` on the four `booster.strings` keys
- [ ] Rename "island" wording in `test/system/booster_test.rb`
- [ ] System tests: picker paging past 36, fold button, comparison chips, phone closing hint, no-season canister label
- [ ] Optional if safe (Findings 11, 16, 3): render only the connecting outlet in the booster; count rendered pips instead of TS `RESERVE_PIPS`; dispose the face loader on disconnect

**Acceptance Criteria:**
- Given the sweep is applied, when the verification commands run, then all pass and no player-visible behaviour differs.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-27 - Review pass
- verdicts: 31 findings - high 0, medium 0, low 5, false 12, maybe-false 0 (others folded below as rejected or deferred)
- findings:
  - `[false]` `[reject]` stopSwap disposes the timers so a later swap never runs (blind) - stopSwap is called only from disconnect and connect creates fresh timers (confirmed by edge-case hunter and grep)
  - `[false]` `[reject]` RESERVE_PIPS cap dropped is a behaviour change (blind, edge-case x2, intent) - the info controller lights only rendered `.booster__pip` nodes and the server renders exactly 10; the plan lists the removal as an optional item
  - `[false]` `[reject]` trade-swap rename may have missed references (blind) - grep of app, test, config finds none left
  - `[false]` `[reject]` nextResult deleted without evidence it was dead (blind) - no reference left in app or tests; the review found it dead
  - `[false]` `[reject]` booster root wiring has no assertion (blind, verification-gap) - boosters_controller_test.rb already loops BOOSTER_ACTIONS checking data-action, selector and outlet, plus booster-info
  - `[false]` `[reject]` phone tests do not restore window size (blind) - application_system_test_case.rb teardown resizes to SCREEN_SIZE
  - `[false]` `[reject]` cancelable removal alters behaviour (blind, intent, verification-gap) - Stimulus dispatch is cancelable by default
  - `[low]` `[patch]` blank line left where BANNER_TIERS and later() were (blind, edge-case) - collapsed
  - `[low]` `[patch]` trailing writeData(null) call has no assertion (blind) - assertion added
  - `[low]` `[reject]` celebration controller still writes position.textContent directly (blind) - those two writes are unconditional by design; switching to writeText would change write-if-changed behaviour, against byte-for-byte
  - `[low]` `[reject]` trade_board_markup imports Dataset type from booster_markup (blind) - type-only import, no runtime coupling, churn for no rule
  - `[low]` `[reject]` zero test only covers four keys, wiring helper lacks direct test, removed comments carried behaviour, tests mixed in refactor, BANNER_TIERS shared by rays (blind) - the plan names exactly these four keys; helper covered through both controller tests; no named harm
  - `[low]` `[defer]` no test pairs the burst class names with the stylesheet (verification-gap) - one assertion in a swap system test would settle it
  - `[false]` `[reject]` new system tests never ran against old code (intent) - descriptive; they pin existing behaviour the review named as untested

## Verification

**Commands:**
- `npm run test:js` and `npm run typecheck` -- expected: pass
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react bin/ci` -- expected: pass
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_markup_apis` -- expected: pass
- each system test file for booster/trade board, one at a time (`CHROME_BIN=/usr/bin/chromium`) -- expected: pass

## Auto Run Result

- Summary: the review's Do list applied as cleanup (shared Ruby wiring helper; shared screen_timers, templates, dom_writes, screen, trade_board_markup modules; stepperKey moved; nextResult deleted; one cancelable rule via the Stimulus default; send child render; trade-board ring/confetti/flash rename; comment cleanup; French zero forms; island rename; five new system tests and a trades wiring test). Optional: TS RESERVE_PIPS dropped; booster single-outlet render and face-loader disposal not done (focus microtask risk; retry disposal would strand asked keys).
- Review: 4 lenses; 2 patches (blank lines, missing assertion), 1 defer (burst class pairing test), the rest rejected with reasons in the triage log.
- Follow-up review recommended: false.
- Verification: typecheck clean; vitest 717 passed; zeitwerk, packwerk, markup check clean; bin/ci all green (Rails 3203 runs, 0 failures) except bundle audit (net-ssh advisories, unrelated); system tests each file separately, 0 failures, booster and booster_screen three times.
- Residual risk: swap timers now fire one microtask after their delay.
