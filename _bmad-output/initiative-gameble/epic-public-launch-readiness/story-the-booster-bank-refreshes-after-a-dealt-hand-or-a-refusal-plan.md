---
title: 'The booster bank refreshes after a dealt hand or a refusal'
type: 'bugfix'
ticket: '31'
created: '2026-10-13'
status: 'built'
baseline_revision: '47f2a2ed70e0b08f8d0d427b43d2de6210df4380'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The booster island's bank goes stale until a reload in two cases: the countdown reaching zero while cards are dealt (the refresh at zero only runs while the island is idle with no hand, so an empty reserve keeps "00:00" and a disabled "Ouvrir le suivant"), and a `no_pack_available` refusal, which zeroes the count locally but keeps the page's old next-pack time (null when the reserve was full: no countdown, no refresh ever).

**Approach:** The booster screen answers its bank in JSON (`GET /:locale/booster.json`, read-only, same shape as the props' `bank`). The island fetches it with any refusal, and when the countdown reaches zero while a hand is dealt it owes a fetch that it makes once the hand is put away (every card revealed in a row, every card stored in the tray on the phone) and nothing runs. The fresh bank replaces the island's bank and is announced through `gameble:bank-changed`; a dealt hand is never refreshed away.

## Boundaries & Constraints

**Always:** The countdown reaching zero with the island at rest and no hand (phase sealed or empty, nothing running) still refreshes the page as today. A fetched bank never touches the hand (answer, revealed, stored, phase "dealt"). A fresh bank that arrives after another bank change (an opening's answer, another fetch) is dropped. With phase sealed or empty, the phase follows the fresh bank (available > 0 → sealed/"sealed", 0 → empty/"waiting"); phase dealt and opening are left as they are. The JSON carries no database id; times are UTC ISO 8601 with milliseconds; every action authorized (the booster policy's `show?`); the GET writes nothing. Islands talk only through `gameble:*` events in `app/frontend/lib/events.ts` (no new event needed).

**Never:** No page refresh (Turbo visit, reload) while a hand is dealt. No local guess of the bank (no bump of `available` at zero). No new system test; system tests are not run. No change to the opening exchange (`packs#create`). No planning ids in code or tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Zero at rest | phase sealed or empty, idle, countdown >0→0 | page refreshed a second later (as today) | none |
| Zero, hand dealt, not put away | phase dealt, a card face down (row) or on the pile (phone) | nothing at zero; fetch owed; no page refresh | none |
| Owed, hand then put away | owed fetch, last card revealed (row) / stored (phone), nothing running | bank fetched; reserve count, countdown and "Ouvrir le suivant" follow it; `gameble:bank-changed` sent | fetch failed or bad shape → bank kept as it was |
| Zero, hand already put away | phase dealt, hand put away, idle (also a hand shown again via `?pack=`) | bank fetched at once (a second after zero), no page refresh | as above |
| Zero during an opening | phase opening or an opening/reveal/store running | fetch owed, made once the next hand is put away | none |
| Refusal | `refused` result (any code) | local fallback as today (`no_pack_available` → available 0, reserveFull false, nextPackSize null), then the fetched bank: its count and its countdown; empty→sealed if a pack is available | fetch failed → local fallback kept |
| Stale fetch | a bank change happens while the fetch runs | fetched bank dropped | none |
| JSON endpoint, player | signed-in `GET /en/booster.json` | 200 `{ bank: { available, reserveFull, nextAvailableAt, serverTime, nextPackSize } }` | none |
| JSON endpoint, visitor | signed out | 401 `{ error: { code: "sign_in_required", message } }` | via `ApplicationController#refuse` |

</intent-contract>

## Code Map

- `app/controllers/boosters_controller.rb` -- `show`: add `respond_to`; HTML as now (`@season`, `@opened` only for HTML); JSON renders `{ bank: helpers.booster_bank(bank: @bank, next_pack_size: @next_pack_size) }`. Update the class comment (one line on the JSON answer).
- `app/helpers/boosters_helper.rb` -- extract the `bank:` hash of `booster_props` into public `booster_bank(bank:, next_pack_size:)` (uses `opening_time` from `PacksHelper`, already used here); `booster_props` uses it and adds `bankUrl: booster_path(format: :json)`. Update the comment listing the props.
- `app/frontend/lib/booster_props.ts` -- `BoosterProps` gains `bankUrl: string` (the screen's bank in JSON). `BoosterBank` is the fetched shape.
- `app/frontend/lib/booster_page.ts` -- `refreshPage()` stays; reuse.
- `app/frontend/lib/opening.ts` -- pattern for a fetch wrapper with an injectable `fetch` and shape guard (`isRecord`); do not change it.
- `app/frontend/components/useBoosterCountdown.ts` -- `useRefreshAtZero(left, canRefresh)` calls `refreshPage()` itself. Turn it into `useAtZero(left, onZero)`: same >0→0 transition rule and one-second delay, calling `onZero()` (latest ref) instead; the island decides. Update its doc comment and the file header.
- `app/frontend/components/Booster.tsx` -- the island. Relevant: `changeBank` (l.321), `refuse` (l.329), `complete` (l.633), `idle()` (l.724), `unlock = () => releaseLock(applyLayout)` (l.271), `applyLayout()` calls at the ends of `revealAll`, `revealAndStoreAll`, `store` (l.688, 720, 778), `useRefreshAtZero` use (l.930), `setPhase`, `setStatus`, `phoneLayout()`, `revealedRef`, `storedRef`, `disposed`.
- `app/frontend/lib/booster.test.ts`, `app/frontend/lib/opening.test.ts` -- vitest style to follow (fake fetch returning `Response`).
- `test/controllers/boosters_controller_test.rb` -- request tests (`sign_in`, `props`, `json_keys`, `travel_to`, `Game::FillBank`, `Game::OpenPack` as in "a player gets the island…").
- `test/system/booster_test.rb` -- `record_requests` (l.55–65) pushes every fetch's `Idempotency-Key`, so a bank fetch after a refusal would add `nil` to `request_keys` (refusal test l.496 asserts size 1). Disabled suite: only adjust the helper; do not run it.

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/boosters_helper.rb` -- extract `booster_bank`, add `bankUrl` -- one bank shape for the props and the JSON.
- [ ] `app/controllers/boosters_controller.rb` -- JSON format of `show` answering `{ bank: … }` -- the island's fresh bank, read-only.
- [ ] `app/frontend/lib/booster_bank.ts` (new) -- pure, no DOM: `fetchBank({ url, fetch? }): Promise<BoosterBank | null>` (GET, `Accept: application/json`, `credentials: "same-origin"`; null on network error, non-2xx, unparsable or wrong shape: `available` number, `reserveFull` boolean, `nextAvailableAt` string|null, `serverTime` string, `nextPackSize` number|null); `handPutAway(layout, revealed, stored)` (phone: non-empty and every card stored; else non-empty and every card revealed); `atZero({ phase, idle, handPutAway }): "page" | "bank" | "owe"` (idle and sealed/empty → page; idle, dealt and put away → bank; otherwise owe); `owedBankDue({ phase, idle, handPutAway })` (idle and phase not opening and (phase not dealt or hand put away)); `phaseForBank(phase, available)` (sealed/empty follow the count; dealt/opening unchanged). File header two lines at most; doc comments only where the name does not carry the rule.
- [ ] `app/frontend/lib/booster_bank.test.ts` (new) -- vitest every matrix decision row and `fetchBank`'s outcomes (good answer read, headers and method, network error, 401/500, HTML, wrong shape → null).
- [ ] `app/frontend/components/useBoosterCountdown.ts` -- `useAtZero(left, onZero)` as in the Code Map.
- [ ] `app/frontend/components/Booster.tsx` -- `bankOwed` and `bankGeneration` refs; `changeBank` bumps the generation; `refreshBank()` fetches and, if not disposed and no bank change since it started, calls `changeBank(fresh)` then applies `phaseForBank` (when the phase changes: status "sealed" or "waiting", and the refusal's reason line cleared); `refuse` clears the owed flag and starts `refreshBank()` after its local fallback; the zero callback acts on `atZero` (`refreshPage()`, `refreshBank()`, or owe); a `whenIdle()` (applyLayout, then the owed fetch when `owedBankDue`) replaces `applyLayout` in `unlock` and at the ends of `revealAll`, `revealAndStoreAll`, `store` and in the media-query listener's `onChange` (a layout change can put the hand away: rows to phone stores the revealed cards, phone to rows counts every revealed card). Update the header comment's bank sentence; add no comment on the new refs, `refreshBank` or `whenIdle` (names carry them).
- [ ] `test/controllers/boosters_controller_test.rb` -- JSON bank for a player (exact hash at a travelled time, no id keys), 401 JSON for a visitor, `bankUrl` "/en/booster.json" in the props.
- [ ] `test/system/booster_test.rb` -- `record_requests` records only requests carrying an `Idempotency-Key`, keeping the helper's existing one-line comment as it is -- the bank fetch is not an opening.

**Acceptance Criteria:**
- Given an empty reserve whose next pack arrives while a hand is dealt and not put away, when the countdown reaches zero, then the screen is not refreshed and the hand stays; when the last card is then revealed (row) or stored (phone), then the island fetches the bank and "Ouvrir le suivant" becomes enabled with the reserve count and the top bar chip at 1.
- Given a `no_pack_available` refusal, when the fresh bank arrives, then the reserve and its countdown are the server's current ones.
- Given the countdown reaching zero at rest with no hand, then the page refreshes as before.

## Implementation Notes

- The fetch after a refusal runs for a `refused` result only (as the matrix says); a `failed` result (outcome unknown) keeps today's behaviour, and a fetch the countdown owed is still made through `whenIdle` when the refusal releases the lock.
- The controller test reads the JSON bank at the props test's time plus four minutes (before the next pack at 14:32), so the hash is exact without crossing a schedule boundary.

## Plan Change Log

### 2026-10-13 — Review loop 1
- Trigger: quick review found (1) the media-query listener kept `applyLayout`, as the Code Map said, so a width change that puts the hand away (phone to rows with every card revealed, rows to phone storing them) leaves an owed fetch unmade and the bank stale; (2) a fresh bank turning empty into sealed after a refusal left the refusal's reason line beside an openable canister; (3) new comments restated names, against AGENTS.md's comment rule.
- Amended: Booster.tsx task (listener calls `whenIdle`; `refreshBank` clears the reason on a phase change; no comments on the new refs and functions), booster_bank.ts task (short header, doc comments only where needed), system-test helper task (no added comment).
- Known-bad state avoided: an owed fetch lost to a layout change; "no booster available" shown with a booster to open.
- KEEP: the previous implementation, saved at `/tmp/claude-1000/-home-teyermann-projets-gameble/ca76515b-abba-49a9-b0f6-e4a2500e0065/scratchpad/t31-keep.diff` (apply it with `git apply` from the repo root, then make only the amendments above): the endpoint and `booster_bank` helper, `useAtZero`, the generation guard, `atZero`/`owedBankDue`/`handPutAway`/`phaseForBank`/`fetchBank` and their vitest, the controller tests, the `record_requests` key filter. Add a vitest-free change only; no new test needed beyond the existing ones unless a pure function changes.

## Review Triage Log

### 2026-10-13 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` media-query `onChange` keeps `applyLayout`, so a layout change that puts the hand away never makes the owed fetch and no later step calls `whenIdle` (the open button is disabled at 0) — real: the Code Map told the listener to keep `applyLayout`; amended the Booster.tsx task so the listener calls `whenIdle`.
  - `[low]` `[bad_plan]` `refreshBank` turning empty into sealed after a refusal leaves the refusal's reason line beside an openable canister — real: only `open()` clears `reason`; the fix is one line, folded into the amended Booster.tsx task.
  - `[low]` `[bad_plan]` new comments restate names (refs, `refreshBank`, `whenIdle`, booster_bank.ts header and docs, the `record_requests` line), against AGENTS.md — real though the files around are commented the same way; amended tasks to drop them.

### 2026-10-13 — Review pass (loop 1)
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` a fetched bank turning a sealed canister empty (after a throttled refusal, the reserve emptied elsewhere) leaves the focus on the canister that leaves — real but needs a throttled refusal racing another tab's last opening; the fix adds a focus branch to `refreshBank`, not worth it for that path.
  - `[low]` `[patch]` the comment above `useAtZero` repeated `atZero`'s doc comment — deleted the two lines.

## Design Notes

"Put away" is read as the hand being complete the way the screen already says it ("INVENTAIRE COMPLET"): every card revealed in a row, every card stored ("Ranger") on the phone. Fetching JSON rather than refreshing the page keeps the hand, the reason line and the live region. The verify's booster system tests are disabled: the island's decisions are proved by vitest on `lib/booster_bank.ts`, the endpoint by the controller test; the existing system test "the countdown reaching zero while cards are dealt leaves the screen as it is" is kept unchanged and still holds by construction (dealt → never "page"), but is not run.

## Verification

**Commands:**
- `npm run test:js` -- expected: all pass, the new `booster_bank.test.ts` included.
- `bin/rails test test/controllers/boosters_controller_test.rb` then `bin/rails test` -- expected: 0 failures, 0 errors.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `npm run typecheck` -- expected: clean.

## Auto Run Result

**Summary:** The booster screen answers its bank in JSON (`GET /:locale/booster.json`). The island fetches it with any refusal, and when the countdown reaches zero while a hand is dealt it owes the fetch until the hand is put away (every card revealed in a row, every card stored on the phone) and nothing runs, a width change included; at rest with no hand the page still refreshes. A fetched bank older than the last bank change is dropped; a sealed or empty canister follows the fetched count (the refusal's reason cleared); a dealt hand is never refreshed away.

**Files changed:**
- `app/controllers/boosters_controller.rb` -- `show` answers `{ bank: … }` in JSON.
- `app/helpers/boosters_helper.rb` -- `booster_bank` extracted, shared by the props and the JSON; props gain `bankUrl`.
- `app/frontend/lib/booster_bank.ts` (new) -- `fetchBank`, `handPutAway`, `atZero`, `owedBankDue`, `phaseForBank`.
- `app/frontend/lib/booster_bank.test.ts` (new) -- vitest of every decision row and every fetch outcome.
- `app/frontend/lib/booster_props.ts` -- `bankUrl` prop.
- `app/frontend/components/useBoosterCountdown.ts` -- `useRefreshAtZero` becomes `useAtZero(left, onZero)`.
- `app/frontend/components/Booster.tsx` -- owed fetch, generation guard, `refreshBank`, `whenIdle`, fetch after a refusal.
- `test/controllers/boosters_controller_test.rb` -- JSON bank, visitor's 401 JSON, `bankUrl`.
- `test/system/booster_test.rb` -- `record_requests` records only opening requests (not run: system tests disabled).

**Review:** pass 1 (quick): 3 findings, all routed bad_plan (layout change losing the owed fetch, reason line left after a fresh bank, comments restating names); plan amended, code re-derived from the kept diff. Pass 2 (quick): 2 findings, 1 low patched (duplicate comment deleted), 1 low rejected (focus after a throttled refusal racing another tab, recorded above). Nothing deferred.

**Follow-up review recommended:** false (patched this pass: 1 low).

**Verification:** `npm run typecheck` clean; `npm run test:js` 25 files, 239 tests passed; `bin/rails test` 2367 runs, 0 failures; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` 695 files, no offenses. Verify coverage: "offers the new pack once the hand is put away" and "a dealt hand is never refreshed away" -- vitest on `atZero`/`owedBankDue`/`handPutAway` (dealt never "page"); "a refusal shows the current bank and its countdown" -- vitest on `fetchBank` and `phaseForBank`, controller test of the JSON bank; the island's wiring is checked by typecheck and review only. The existing system test "the countdown reaching zero while cards are dealt leaves the screen as it is" is unchanged and holds by construction, but was not run (system tests disabled).

**Residual risks:** the wiring in `Booster.tsx` (when `whenIdle` fires, the generation guard, the reason cleared) has no browser test until system tests are rebuilt; on the phone a last revealed card left on the pile keeps the bank owed until it is stored, as the plan defines a hand put away.

