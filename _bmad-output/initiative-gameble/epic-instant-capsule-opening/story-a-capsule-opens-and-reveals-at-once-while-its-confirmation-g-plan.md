---
title: 'A capsule opens and reveals at once while its confirmation goes in the background'
type: 'feature'
ticket: '3'
created: '2026-11-06'
status: 'built'
baseline_revision: '8a628d2e611b7d4e5357c4521a592432924abc47'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md', '{project-root}/_bmad-output/initiative-gameble/epic-instant-capsule-opening/story-the-capsule-screen-carries-the-next-capsule-of-each-reserve-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A touch on a capsule waits for the opening POST before the capsule blasts, which reads as a freeze on phones, and a lost connection cancels the opening with a toast that advises reloading the page.

**Approach:** The booster client reads the held capsule of each reserve (previous story: page value `held`, bank JSON `held`, opening answer `next`) and opens it locally: the touch arms, blasts and deals at once from a provisional answer built from the held capsule, and the reveal uses its faces. The opening POST, naming the capsule's token with an idempotency key, goes through a persistent confirmation queue; when it lands its server data is applied. With no held capsule for the reserve, the current waiting path stays as the fallback.

## Boundaries & Constraints

**Always:** One state module stays the source of truth (`app/frontend/lib/booster*.ts`, pure transitions, tested in vitest); the controller only wires. The queue lives in `localStorage` (wrap every access in try/catch; works without storage, just not across reloads), holds `{ token, key, reserve }` per pending opening, and sends again on failure when the browser fires `online`, when the document becomes visible, on the booster's next connect, and after a short backoff while the screen is open. A queued token is never sent with a new key. The provisional answer decrements the local bank for that reserve. When a confirmation lands: bank, `tierCountsBefore`, first copies, `setTiers` (celebration) and `goalsReached` come from the server; the reserve's held capsule becomes the answer's `next`; the reveal mode (`/packs/:token/reveal`) is sent only after the confirmation landed. While a confirmation of a reserve is pending and that reserve has no held capsule, a touch on it waits for that confirmation (then opens its `next`), never opens through the token-less path. A capsule queued but not yet confirmed is not shown as held again after a reload (the held whose token is queued is skipped and the reserve count reduced by one). Keep every source file under 400 lines (`booster_controller.ts` is at 400: move wiring into a lib collaborator, as `BankRefresh` and `OpeningSequence` do). Strings in en.yml and fr.yml.

**Never:** No change to the server (previous story owns it). No React, no markup built in script: faces stay server HTML cloned through templates (`BoosterFaces.keepFaces`). No retry with `setInterval` that outlives the controller (use `ScreenTimers`). Never drop a queued confirmation on a network failure; drop it only on a server answer (opened, or refused with a code).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Instant open | held capsule for the reserve, network fine | arm, blast and deal start with no network wait; reveals show held faces; POST `?pack=<token>&reserve=` with `Idempotency-Key` sent once | No error expected |
| Confirmation lands during the hand | server answer arrives before the last reveal | bank, counts, first copies, set tiers and goals adopted; celebration plays at the hand's end as today | No error expected |
| Confirmation lands after the hand | answer arrives after every card is revealed | pending celebration and goal toasts play when it lands | No error expected |
| Server answers other cards | answer's card slugs differ from the provisional ones | the hand follows the server: answer and faces replaced; revealed state reset only for the cards that changed | No error expected |
| Offline open | held capsule, fetch rejects | the hand deals and reveals fully; no toast; the queue keeps the entry and sends it on `online`, on visible, on next connect | the entry is kept |
| Reload before confirmation | queue holds token T, page held is T | T is not offered again; the queue sends T; the next touch on that reserve waits for it | No error expected |
| Refused confirmation | server answers `pack_not_available` or another refusal code | entry dropped, bank refreshed from the bank JSON | the refusal message is announced politely, no "Ouverture annulée" toast |
| No held capsule | held null for the reserve and nothing pending | current waiting path, token-less POST | failure copy: "Pas de connexion. Votre capsule est intacte. Réessayez." (en: "No connection. Your capsule is safe. Try again.") instead of the reload advice; no "Ouverture annulée" title |
| Next capsule | answer's `next` | the reserve's held capsule is `next`, so the following touch is instant too | No error expected |

</frozen-after-approval>

## Code Map

- What the previous story shipped (commit 8a628d2e): the booster root carries `data-booster-held-value` (JSON `{ standard: Held | null, special: Held | null }`), `GET /:locale/booster.json` answers `{ bank, held }`, and the JSON opening answer carries `next: Held | null` for the opened capsule's reserve. `Held` = `{ pack: { token, kind, cardBack, url, revealUrl }, cards: OpeningCard[], tierCountsBefore }`, the same shape as the head of `OpeningAnswer`. `POST /:locale/packs?pack=<token>&reserve=<r>` with `Idempotency-Key` opens exactly that capsule; a token this player already opened answers that capsule again (no credit); an unknown token answers 422 `pack_not_available`. A held capsule's `firstCopy` matches what the opening answers. See `app/helpers/held_packs_helper.rb`, `app/helpers/packs_helper.rb`, `app/controllers/packs_controller.rb`.
- `app/frontend/lib/opening.ts` -- `OpeningAnswer`, `sendOpening` (add an optional `pack` token to the query), `isAnswer` (reuse to validate a held capsule: `{ pack, cards, tierCountsBefore }`, and the answer's `next`).
- `app/frontend/lib/booster_opening_sequence.ts` -- `OpeningSequence.open()`: today sends then awaits `Promise.all([request, pause(ARM_MS)])`; the held path skips the wait. `refuse()` dispatches the "refused" toast: keep it only for the fallback path's real refusals. Keep `laterInThisDeal`/haptics from story 1 intact.
- `app/frontend/lib/booster_opening.ts` -- `openingAnswered`, `openingRefused`, `withoutReserve`, `reserveAfterOpening`, `keyFor`; add the provisional and confirmed transitions here or in a new module (file is 238 lines).
- `app/frontend/lib/booster_state.ts` -- `start`, `celebrate`, `completed` (hand done → celebration from `celebrationPending`), `bankChanged`.
- `app/frontend/lib/booster_types.ts` -- `BoosterState` (add held capsules per reserve and pending confirmations), `BoosterStart`.
- `app/frontend/lib/booster_start.ts`, `app/frontend/lib/booster_markup.ts` -- read the new `held` value; `app/frontend/controllers/booster_controller.ts` (400 lines: add the `held` value and wire a new collaborator, moving code out to stay under the limit).
- `app/frontend/lib/booster_bank.ts` (`fetchBank`) and `booster_bank_refresh.ts` -- the bank JSON now carries `held`: keep it in state.
- `app/frontend/lib/booster_reflect.ts` -- `recordReveal` sends the mode when all cards are revealed: defer until the confirmation landed.
- `app/frontend/lib/booster_faces.ts` -- `keepFaces(answer)` from a held capsule.
- `app/frontend/lib/screen_timers.ts` -- `later`, `wait`, `dispose`.
- `app/frontend/lib/booster_fixtures.ts`, `booster_opening_sequence.test.ts`, `booster_opening.test.ts`, `opening.test.ts` -- fixtures and patterns for vitest (`// @vitest-environment happy-dom` when a test needs `window`).
- `config/locales/en.yml`, `fr.yml` -- `booster.strings.failed`, `booster.strings.refused_title`.
- `test/system/booster*_test.rb` -- system tests of the opening; they cannot run in this container (no matching chromedriver): keep them consistent by reading them, do not run them.

## Tasks & Acceptance

**Execution:**
- [ ] new `app/frontend/lib/opening_queue.ts` (+ test) -- persistent confirmation queue with storage guard and send policy
- [ ] state transitions for held capsules, provisional opening and confirmation (+ tests for every matrix row)
- [ ] `booster_opening_sequence.ts` -- held path without network wait; fallback path unchanged but for the copy
- [ ] controller wiring through a lib collaborator; `held` value read at start and from the bank JSON
- [ ] `booster_reflect.ts` -- reveal mode sent after confirmation
- [ ] locales -- failure copy

**Acceptance Criteria:**
- Given a held capsule, when the player touches it with the network cut, then the cards deal and reveal with their faces, and the opening is confirmed once the network returns, with no second capsule opened.

## Verification

Ruby (only to dump pages if needed) runs through `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb '<command>'`.

**Commands:**
- `npm run test:js` -- expected: green, new tests for each matrix row
- `npm run typecheck && npm run format:check && npm run lint:css` -- expected: clean
- `script/check_file_sizes && script/check_planning_references` -- expected: clean
- `/tmp/claude-0/-home-user-gameble/f1501461-4159-5967-b2df-065d6bef55e8/scratchpad/rb 'bin/rails test test/controllers/boosters_controller_test.rb test/i18n_test.rb'` (or the i18n test file that exists) -- expected: green

## Implementation Notes

- New lib modules: `opening_queue.ts` (persistent queue, 15 s send timeout, backoff 2/5/15/30 s), `booster_held.ts` (held routing, provisional opening, confirmation, refusal), `booster_confirmations.ts` (resends on online, visible, connect, backoff), `booster_opening_parts.ts` (wiring, keeps the controller under 400 lines).
- The root's `held` and `bank` Stimulus values follow the state, so a Turbo-restored snapshot never offers a confirmed capsule again.
- The fallback path's network failure shows a toast with the new copy and no "Opening cancelled" title; real refusals keep the title.
- System tests in `test/system/booster_test.rb` and `booster_reserves_test.rb` were rewritten for the background confirmation (held path, cut network, reload before confirmation, refusal, opened elsewhere) and have NOT been run: no chromedriver matching the container's Chromium could be fetched.

## Review Triage Log

Pass 1 (quick): 1 high, 4 medium, 4 low.

- high, patch — a Turbo-restored booster snapshot offered an already confirmed capsule as held and reopened it by token: the root's `held` and `bank` values now follow the state.
- medium, patch — a hanging fetch blocked every resend: queued sends abort after 15 s and count as a network failure.
- medium, patch — a refused confirmation left the hand provisional and an owed reveal forever: cleared when the refused token is the hand on screen.
- medium, patch — the other reserve's held capsule opened with stale tier counts: the provisional hand starts from the live counts.
- medium, defer — a confirmation landing after its hand left the screen drops the set celebration (deferred-work.md).
- medium, defer — leaving an offline, unconfirmed hand for a card's detail loses it on return (deferred-work.md).
- low, defer — the queue is not tied to a player; to clear on sign-out with the offline-screen story (deferred-work.md).
- low, rejected — `pendingKey` survives held openings: it is the replay key of a lost token-less opening and must stay to avoid a double opening.
- low, patch — a one-shot read of background state in `booster_reserves_test.rb` now uses `eventually`.
