---
title: 'Refactor sweep'
type: 'refactor'
ticket: '5'
created: '2026-10-19'
status: 'built'
baseline_revision: '32fee1d122754f42610d4e35418a8912af0ef370'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** The five builds of epic-easier-trades (18.1 the friend chooser, 18.6 the open request, 18.2 the cross-collection chips, 18.3 the phone fold, 18.4 the paged picker and its faces endpoint) left residual risks and rejected review findings in their plans, and the epic has one entry in `deferred-work.md`; each must end fixed, recorded or dropped with a reason. Two are worth fixing in code: a face request that never settles keeps its keys marked in flight for the board's lifetime, so those cards keep their placeholder until the page is left (18.4); and `TradesController#create` and `#counter` learn the sent offer by assigning a local from inside the `with_sides` block (18.6, rejected as a restructure).

**Approach:** Behaviour-preserving cleanup inside the epic's code. The faces request moves from `TradeBoard.tsx` into `app/frontend/lib/trade_faces.ts` as a function that gives up after a timeout (so the keys are released and asked again on the next render, like a failed request), with vitest coverage of success, non-200, network failure and timeout. `with_sides` becomes a function returning the parsed sides as a `Success([offer, request])` or the existing `Failure(:invalid_offer | :invalid_request)`, which `create` and `counter` bind to their operation and read the offer from, with no closure. The worst scroll frame near the 100 ms bound (18.4) is re-measured with 18.4's harness on a freshly seeded database; a CSS-only containment of off-screen picker cards is kept only if the measurement shows it lowers the worst frame without changing what is shown, otherwise the risk is recorded with the figures. Every other finding is recorded or dropped with its reason in Implementation Notes. No URL, markup, copy, operation result or failure code changes; the epic's files carry no planning ids today, and none are added.

</intent-contract>

## Implementation Notes

Oneshot: three small code changes (one TypeScript extraction with its test, one controller restructure, at most a few CSS lines) and the disposition of each recorded finding, under 100 lines in all.

Changed:
- `app/frontend/lib/trade_faces.ts` -- `fetchFaces({ url, fetch, timeout })` asks for a batch of faces in JSON with the session's cookies under `AbortSignal.timeout` (10 s), and answers `{}` on a network error, a non-200, a malformed body or the timeout, never rejecting. `TradeBoard.tsx#requestFaces` uses it and releases the batch's keys once it settles, so a stalled request no longer pins its keys in flight: they are asked again the next time those cards are rendered, as after a failure. `trade_faces.test.ts` covers the answer, the request's headers and signal, the failures and the timeout.
- `app/controllers/trades_controller.rb` -- `with_sides` (which yielded) becomes `sent_sides`, returning `Success({ offer:, request: })` or the same `Failure(:invalid_offer | :invalid_request)`; `create` and `counter` bind it to `Game::ProposeTrade` / `Game::CounterTrade` and read the offer for the toast from it, with no local assigned from inside a block (18.6 triage, rejected there as a restructure).
- `app/frontend/lib/trade_board.ts` -- `labelledChips(side, labels)` pairs a side's chips with that side's labels, typed per side; `TradePicker.tsx` renders the compare chips from it instead of widening the labels to `Partial<Record<Chip, string>>` (18.2 triage, rejected there for lack of a typed accessor). Vitest covers both sides.

Measured (18.4's harness, re-seeded scratch database `gameble_dev_w1805`, Hugo and Lea holding 3,000 distinct cards each of a 4,000-card season, development build, headless Chrome at 390×844 with a 4× CPU slowdown, medians of 3, on a machine shared with other builds): counter page DOMContentLoaded 0.32 s, open friend picker 53 ms (36 cards in the DOM), first 9 faces 202 ms after opening, search 53 ms, clear 105 ms, chip on 38 / off 49 ms, scroll worst frame 89 ms (runs 94, 89, 78; mean 25 ms), close 107 ms. Within 18.4's threshold and in line with its figures; faces still arrive through `fetchFaces`. No CSS containment was added: `content-visibility: auto` on a picker card implies paint containment, which would clip the picked card's lime ring (`inset: -4px`) and the toggle's focus outline, so it is not the behaviour-preserving change the plan allowed.

Every finding of the epic, with its end:
- 18.4, a face request that never settles -- fixed (above).
- 18.4, worst scroll frame near 100 ms -- recorded in `deferred-work.md` with the figures and the levers left (smaller pages or face batches, fewer controllers per face).
- 18.4, draft restore checked by reading only -- dropped: the repo has no React component tests and system tests are disabled; the board asks for every line's missing face whenever its lines change, mount included.
- 18.4, one `bin/ci` run with two errors that did not recur -- dropped: not reproduced by 18.4's two later runs nor by this sweep's run.
- 18.4, timings from a development build in headless Chrome -- for the author on staging, on a phone.
- 18.3, each search keystroke re-renders the board -- dropped: measured by 18.4 and here with 3,000 cards a side, a search step takes about 50 ms.
- 18.2, chip labels widened to `Partial<Record<Chip, string>>` -- fixed (above).
- 18.2, no running test for "placed card hidden" and "Clear" -- dropped: same lack of component tests; both read from the selection and `clearedFilters`, which vitest covers.
- 18.2, the game unit for "duplicates" and the chip labels, for the author to approve -- left to the author's review of 18.2 (status `built`), not cleanup.
- 18.6, the sent offer captured through a closure -- fixed (above).
- 18.6, follow-up review recommended for the Stimulus send gate and the island's help line -- dropped: 18.6's own patches pinned both (`sendable` in vitest, the counter island's `help` prop in `trades_controller_test.rb`).
- 18.6, a stale accept of an open request repeats the instruction in the error, the toast and the line; the help line not tied to the send button for screen readers; the open-request copy and failure code for approval -- dropped: cosmetic on a stale tab, reading order already carries the help line, and 18.6 is `done`.
- 18.1, the chooser heading not focused on open and no focus row for it in EXPERIENCE.md -- dropped: the chooser is reached by a full Turbo visit and starts focus where every other screen does; changing it is a UX decision, not cleanup.
- `deferred-work.md`, the trade list's "first game +n" summary -- kept open: a copy-format change the author deferred at slicing, not cleanup.
- `deferred-work.md`, the TradeBoard page weight -- already resolved by 18.4.
- Planning ids -- none in the epic's code, views, styles or tests (grep for AD-, CAP-, R-, epic, story); nothing to remove.

## Plan Change Log

## Review Triage Log

### 2026-10-19 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` `sent_sides` returns `Success({ offer:, request: })`, not the `Success([offer, request])` the intent names — same behaviour (failures pass through `bind` unchanged, the keys match the operations' keywords), and the named hash reads as `sides.value![:offer]` where a pair would need positional unpacking; the only fix would edit the plan or make the code less clear. Noted under Auto Run Result.
  - `[low]` `[patch]` `fetchFaces` claims `{}` on a malformed body but no test sends one — the failures test now includes a 200 HTML answer, whose `response.json()` rejects inside the `try`.
  - `[low]` `[reject]` the worst scroll frame has an after series only, no same-harness before — no rendering code or CSS changed, so there is nothing to compare; 18.4's figures on the same harness and data shape stand as the before, and re-seeding for a baseline would not change any decision.

## Verification

**Commands:** (prefix every Rails command with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w1805`; never run system tests; run `bin/ci` and full `bin/rails test` through the shared `ci-slot.sh` wrapper)
- `npm run test:js` and `npm run typecheck` -- expected: all pass
- `bin/rails test test/controllers/trades_controller_test.rb` -- expected: pass
- `bin/ci`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` -- expected: green

**Manual checks:**
- 18.4's measurement harness (seeded players with 3,000 distinct cards each, headless Chrome at 390 px, 4× CPU slowdown) on the counter page: open, filters and scroll within 18.4's threshold, worst scroll frame before and after recorded.

## Auto Run Result

- **Summary:** cleanup sweep of epic-easier-trades. The faces request moves into `trade_faces.ts` as `fetchFaces`, which gives up after 10 s and never rejects, so a stalled request no longer pins its cards' keys in flight; `TradesController` gets the sent sides as a `Success`/`Failure` value instead of capturing the offer from inside a block; the picker's compare chips come from a typed `labelledChips`. Every finding left by the epic's five plans and its `deferred-work.md` entries is fixed, recorded or dropped with its reason in Implementation Notes; the worst scroll frame, re-measured at a median of 89 ms, is recorded in `deferred-work.md`.
- **Files:** `app/frontend/lib/trade_faces.ts` (+ test: `fetchFaces`), `app/frontend/components/TradeBoard.tsx` (requests faces through it), `app/controllers/trades_controller.rb` (`sent_sides`), `app/frontend/lib/trade_board.ts` (+ test: `labelledChips`), `app/frontend/components/TradePicker.tsx` (compare chips from it), `_bmad-output/initiative-gameble/deferred-work.md` (scroll frame entry).
- **Review:** quick; 3 low findings: 1 patched (malformed-body test), 2 rejected (the sides' hash shape against the intent's array wording, kept for readability with identical behaviour; no same-harness "before" for a scroll measurement no code change could move). Follow-up review not recommended (no high or medium patched).
- **Verification:** `bin/ci` green (2826 runs, 0 failures); `npm run test:js` 471 passed; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check` clean; `trades_controller_test.rb` 58 runs green; 18.4's browser harness re-run on a re-seeded database, every figure within 18.4's threshold.
- **For the author to check on staging:** faces still fill in as a picker scrolls on a real phone; the scroll smoothness entry in `deferred-work.md` is best settled there.
- **Residual risks:** the timeout and release path is covered by vitest only, not seen stalling in a browser; the scroll frame stays near its bound (recorded).
