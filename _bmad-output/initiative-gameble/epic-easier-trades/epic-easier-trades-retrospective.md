---
epic: epic-easier-trades
date: 2026-10-20
verdict: accepted
criteria: declared
headless: false
---

# Retrospective: Trades easy to start and to fill

## Epic summary

Epic `epic-easier-trades` (18), CAP-11, from GitHub issue 63 points 1, 2, 4 and 5. Six tickets, all `done` (the author's review of 2026-10-20, commit 10da0601); `pending_tickets` is empty, none left at `built`.

| Ref | Ticket | Code commit | Churn (code, non-plan) | Review |
|---|---|---|---|---|
| 18.1 | A new trade from the Trades tab | fa43567e | 9 files +241 −2 | quick |
| 18.6 | An open trade request | 1ff11cc9 | 20 files +404 −71 | thorough, follow-up recommended |
| 18.2 | Trade filters across both collections | d338c64a | 8 files +261 −51 | quick |
| 18.3 | The picker's filters on the phone and across reopenings | 5bf2a4dd | 9 files +201 −38 | quick |
| 18.4 | A light trade board with thousands of cards | 13aa8b58 | 12 files +475 −89 | quick |
| 18.5 | Refactor sweep | 6b7a9557 | 7 files +97 −29 | quick |

**Ranges.** The plans' baselines interleave with other epics' commits (parallel lanes), so each ticket's range is its own code commit (`<sha>^..<sha>`), identified from the plan baselines and commit subjects; `git_evidence.py` ran once per commit. The combined patch excludes `_bmad-output/`.

**Evidence inventory.**
- Available: epic file with Done when, initiative and spec CAP-11, six plans (Intent, triage logs, Verification, Auto Run Result), the six commits, `deferred-work.md`, `pending-approvals.md`, release tags and the deploy workflow.
- Missing: session logs, so process lessons rest on the plans' own triage and notes only. No browser walk-through of the flows by this retro (see Behavior verification).

## Findings

### Spec-to-implementation reconciliation

- **S1. Done when 6 not met for four tickets.** fa43567e (18.1) and 1ff11cc9 (18.6) are in `v0.1.1` / `deployed/production`; d338c64a, 5bf2a4dd, 13aa8b58, 6b7a9557 (18.2–18.5) are only in the pre-release `v0.1.3-rc.1` (staging). Production deploys on a published release (`.github/workflows/deploy-production.yml:14-17`). Disposition: defer to the next release; it is the only criterion that fails.
- **S2. Done when 4 met on medians, one run over the bound.** Threshold and before/after recorded in `story-a-light-trade-board-…-plan.md` (21 MB → 1.49 MB, picker open 8.8 s → 43–51 ms); worst scroll frame median 89 ms, one 18.4 run at 107 ms over the 100 ms bound; measured in headless Chrome at 4× CPU slowdown, not a real phone. Already deferred (`deferred-work.md:229-233`). Disposition: defer, settle on a real phone on staging.
- **S3. Done when 5 met in pieces, no whole-flow test.** Server refusal of an empty-sided accept (`packs/game/app/operations/game/accept_trade.rb:37-39`, tests `test/packs/game/trade_accept_counter_expire_test.rb:298,327`, `test/controllers/trades_controller_test.rb:931`), ACCEPTER hidden (`app/views/trades/_board.html.erb:45-49`). No single test sends, counters and accepts. Disposition: accept (system tests are disabled project-wide; covered by `epic-public-launch-readiness` 7.39).
- **S4. 18.6's author approvals never recorded.** The plan's "For the author to approve" items (failure code and copy, send reason, cancel toast, neutral wording) were dropped by the 18.5 sweep as "18.6 is done"; `pending-approvals.md` has no entry. Disposition: fix now (record them for the author).
- **S5. Built but unspecified, all plan-recorded:** cancel toast for an open request (`app/controllers/trades_controller.rb:125`), new `Catalog::PublishedCardSeasonIds`, picker scroll-to-top on filter change, 10 s face timeout (`app/frontend/lib/trade_faces.ts:3`). Disposition: accept.
- **S6. Specified but dropped:** `Game::OpenTradesByFriend` unused by the chooser (plan Implementation Notes); chooser heading focus (18.1 triage, a UX decision); "first game +n" list summary (`deferred-work.md:217-221`, still open). Disposition: accept; the summary stays deferred.

### Diff-scope review (`bmad-review`: adversarial, edge-case, verification-gap; A–E re-checked at HEAD)

- **A. A closed open request still reads "À choisir" in the trade list.** `app/helpers/trades_helper.rb:28-33` returns `trades.row.to_choose` on an empty side without checking the trade is open; the board gates the same label on `open?`. A declined, cancelled or expired open request shows "Portal contre À choisir" in the recent group. The test at `test/controllers/trades_controller_test.rb:946-957` matches only "À vous de choisir|À choisir par". Seam 18.6 × list. Disposition: fix now.
- **B. End in the picker renders every match and fires every face batch at once.** `app/frontend/components/TradePicker.tsx:155-163` grows the page to the last match; `rendered` then holds all of them and `onFacesNeeded` (`:96`) asks for all; `TradeBoard.tsx:137-147` starts every 60-key batch in one loop with no concurrency cap. 3,000 cards → ~50 parallel `/trades/faces` GETs. Seam 18.4 × keyboard grid. Disposition: fix now.
- **C. A failed or timed-out face batch is never retried.** `fetchFaces` resolves `{}` on any error (`app/frontend/lib/trade_faces.ts:33-41`); `TradeBoard.tsx:140-144` drops the keys from `pendingFaces` without adding them to `knownFaces`, and requests rerun only when `lines` or `rendered` change. Cards on the board and the open page stay blank. Seam 18.5 timeout × 18.4 fetching. Disposition: fix now.
- **D. The faces GET has no rate limit.** `app/controllers/trades_controller.rb:2-4` throttles only `create counter accept decline cancel`; `faces` renders up to 60 card components per call. Disposition: fix now, with B.
- **E. A stale chooser row gives a 404 instead of the not-friends refusal.** `app/controllers/trades_controller.rb:26` raises `RecordNotFound` when the friendship ended; `create` returns `:not_friends` for the same case. The chooser makes this path common (it refreshes only on `trades-updated`). Disposition: fix now.
- **F. Picker filters reset when a refused send reloads the board** (`TradeBoard.tsx:123`, not saved with the draft). Disposition: defer; depends on whether a refusal reload is "the same trade".
- **G. No debounce or abort on face requests per keystroke; the face cache is never trimmed** (`TradeBoard.tsx:130-147`, `TradePicker.tsx:96`). Disposition: defer, efficiency.
- **H. A batch of 60 long slugs can approach the 8 KB request line** (`trade_faces.ts:20-23`). Low confidence. Disposition: fold into the fix of B by lowering the batch size.
- **I. Counters that leave one's own side empty can keep a nothing-reserved trade open by resetting its expiry** (`packs/game/app/operations/game/counter_trade.rb:7,30`). Product question, not a crash. Disposition: open question.

### Verification gaps

- **V1–V4.** The island and Stimulus behaviours added by 18.3, 18.4 and 18.6 are covered only through pure helpers in `app/frontend/lib/*`: the send gate of an open request (`trade_send_controller.ts:14`), filters kept across reopenings (`TradeBoard.tsx:123,300`), the phone fold, the 36-card page cap, face replacement and pending de-duplication. Reverting any of them ships green. The repo has no React component tests and system tests are disabled. Disposition: defer to 7.39 (system tests rebuilt), with these flows named.
- **V5.** The 10 s default is never exercised (the test passes `timeout: 5`). Disposition: accept.
- **V6.** The regex at `trades_controller_test.rb:946-957` is too narrow to see A. Disposition: fix now, with A.

### Aggregate views

- **Architecture delta.** `bundle exec packwerk check`: no offenses. One new Catalog query read from the app layer; no new `gameble:*` event; `faces?` added to `TradePolicy` (`app/policies/trade_policy.rb:4`). Clean.
- **Pattern divergence against AGENTS.md.** No write outside an operation; the two new GETs only read; faces keyed by `slug--sN`, no ids (asserted at `trades_controller_test.rb:477`); i18n-tasks clean; no `style=`; no comments added. Clean.
- **Duplication.** The empty-side rule lives in four places (`trade_steps.rb:9-10`, `trade_board.ts:47`, `_board.html.erb:45`, `accept_trade.rb:37-39`); game-unit "duplicates ≥ 2" in three (`packs/game/app/queries/game/collection_states.rb:27-43`, `held_games.rb`, `trades_helper.rb:209-214` + `trade_board.ts:130`). Server and island must agree, so some repetition is structural. Disposition: accept; A is the cost of one copy missing the `open?` gate.
- **Size growth.** `TradePicker.tsx` 260 → 404 lines, edited by every ticket 18.2–18.5, now holding dialog lifecycle, search, fold, chips, paging, roving keyboard grid, selection and face requests (6 effects). `TradeBoard.tsx` 257 → 311 (draft persistence, event bridge, face cache, filters). `trades_helper.rb` 190 → 225 mixes refusals, labels, key parsing, face rendering and island props. Disposition: defer to `epic-human-readable-codebase` as named candidates (picker paging + face requests out of `TradePicker`; props builder out of `TradesHelper`).

## Behavior verification

- Ran `bin/rails test` on the trade controller, the trade operation tests and `published_card_season_ids_test.rb`: 146 runs, 1,272 assertions, 0 failures. Ran vitest on `app/frontend/lib/trade_*` and the components folder: 61/61 passed.
- The author checked 18.2 on the desktop and the phone on staging (`pending-approvals.md:15`, settled 2026-10-20).
- Not exercised by this retro: the chooser, the open-request round trip, the phone fold and the 3,000-card board in a browser. 18.3's DOM rows were checked by an uncommitted headless Capybara script (its plan, Implementation Notes). Recorded as never checked here, not as clean.

## Previous-retro follow-through

The previous epic in build order, `epic-recognizable-sets`, has no retrospective file yet (`epic-recognizable-sets-retrospective.md` absent): nothing to follow through on because the file is missing, not because it had no items.

## Action items

Proposed by the retro; the author's decisions of 2026-10-20 are marked on each. Items 1–4 were applied directly, without tickets: the list hides "À choisir" on a closed trade; face batches load two at a time, the latest first, are retried twice with a growing delay and become requestable again after; the faces endpoint is limited to 120 requests a minute on its own counter and asks for 36 keys at most; a draft for someone no longer a friend gets the not-friends refusal instead of a 404.

1. **Done — Fix A + V6**: gate "À choisir" on `row.open?` in `TradesHelper#trade_side_title`, show "—" otherwise, and widen the test. Owner: next `bmad-build` (bug ticket in this epic).
2. **Done — Fix B + D (+ H)**: cap concurrent face batches in `TradeBoard`, never render or request beyond the page the keyboard jump needs, rate-limit `faces`, and lower the batch size enough to bound the URL. Owner: next `bmad-build` (bug ticket).
3. **Done — Fix C**: a failed batch's keys become requestable again (retry on next render, or a bounded retry), and a stale session's HTML answer is treated as failure. Owner: same build as 2.
4. **Done — Fix E**: `new` with a friend no longer befriended returns the `:not_friends` refusal as `create` does. Owner: next `bmad-build` (bug ticket).
5. **Dropped by the author — Record S4**: add the 18.6 approval items (empty-side failure code and copy, send reason, open-request cancel toast, neutral wording) to `pending-approvals.md` for the author. Owner: orchestrator, with the author's go-ahead.
6. **Dropped by the author — Track S2 on a real phone**: add the 18.4 timings check on staging to `pending-approvals.md`. Owner: author.
7. **Waived by the author — Ship S1**: 18.2–18.5 reach production with the next release (`v0.1.3`). Owner: author.
8. **Name V1–V4 in 7.39** so the rebuilt system tests cover the open-request send, filters across reopenings, the phone fold and face paging. Owner: `bmad-ticket` refine of 7.39.
9. **Process lesson**: a refactor sweep must not drop a ticket's "for the author to approve" items as done; it moves them to `pending-approvals.md`. Owner: orchestration process.
10. **Process lesson**: ticket 18.4 changed a fetching model and got a quick review; the two defects that cross 18.4 and 18.5 (B, C) are the kind a thorough review's edge-case lens finds. Pin thorough review for tickets that change how the client loads data. Owner: orchestration process.

## Acceptance verdict

**Accepted**, by the author's decision on 2026-10-20, overriding the machine verdict.

- Machine verdict: rejected. Every ticket is finished and Done when 1–5 are met in the evidence (S2, S3 with their caveats), but Done when 6 ("Shipped to production") fails for 18.2–18.5, which are only in the pre-release `v0.1.3-rc.1` (S1).
- Author: a production release is not needed for this epic; Done when 6 is waived.
- Fix-now findings A–E were fixed the same day in one follow-up commit (see Action items). Criteria declared in the epic file.

## Open questions

Answered by the author on 2026-10-20:

- I: no; a counter that leaves the sender's side empty keeps resetting the expiry, unbounded.
- F: no; a reload after a refused send is not the same trade, and the picker filters reset.
