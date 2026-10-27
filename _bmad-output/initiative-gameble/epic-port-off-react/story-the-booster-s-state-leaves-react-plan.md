---
title: "The booster's state leaves React"
type: 'refactor'
ticket: '2'
created: '2026-10-26'
status: 'built'
baseline_revision: 'd00573be8fc5ecc224a5c85b171dcae8af31eb7e'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-port-off-react/story-the-trade-board-in-stimulus-plan.md'
warnings: ['oversized']
deferred:
  - summary: >-
      "Reveal all" looks enabled while a Légendaire's reveal holds every other activation (its art loading, or its 1.4 s still banner under reduced motion), and a click then does nothing.
    evidence: |-
      `controls().revealAllDisabled` tests `legendary !== null` while `canRevealAll` tests `legendaryRunning`; under reduced motion `legendarySignalled(s, null)` leaves `legendary` null. The island had the same split (BoosterView's `legendary !== null` against Booster's `legendaryRunning.current`), so it predates this change; fixing it changes the button players see, which the port's "no visible change" rule forbids until the Stimulus view lands. One line: `revealAllDisabled: !canRevealAll(state) || …`.
    location: >-
      app/frontend/lib/booster.ts controls / canRevealAll
    severity: low
---

<intent-contract>

## Intent

**Problem:** The booster island keeps its whole state in `Booster.tsx`: about thirty `useState`/`useRef` pairs mirrored by hand, with every rule (when an opening may start, when a card may reveal or be stored, when the layout may change, when the bank is fetched, what gets focus, when the celebration shows) written inline in React callbacks. The Stimulus port (next entry) would have to untangle all of it at once, and AD-16/AD-30 want that state in a DOM-free module tested by Vitest.

**Approach:** Make `app/frontend/lib/booster.ts` the screen's state module, shaped like `lib/trade_board.ts`: one readonly `BoosterState`, a `start(...)`, pure transitions `(state, …) => state` for opening, reveal, Reveal all, store, layout, celebration, bank refresh, navigation lock, zoom, banner and focus, and derived views the view reads. Its current contents (timings, keyframe geometry, pile poses, clocks) move to `lib/booster_*.ts` helpers. `Booster.tsx` keeps one state value, applies transitions, runs the async choreography (animations, timers, requests) and dispatches events; `BoosterView` draws from the state and the derived views. Add the desktop celebration system tests as the net for the swap.

## Boundaries & Constraints

**Always:**
- `test/system/booster_test.rb`: every existing test passes, and `git diff <baseline> -- test/system/booster_test.rb` shows only added tests (and helpers they need) after the existing ones.
- `lib/booster.ts` touches no DOM and no clock: no `window`, `document`, `performance`, `matchMedia`, `fetch`, timers, `crypto` or `location`; the time (`now`), the layout the width asks for, "focus is inside the screen", "motion is reduced", the idempotency key and composed strings are arguments. It imports types and pure helpers only.
- Every transition returns the same object when nothing changes (as `trade_board.ts` does), so the driver can skip a render.
- Each state field has one writer: the module's transitions. `Booster.tsx` writes no state except by applying a transition; it keeps refs only for DOM elements, timers/disposal (`useIslandTimers`), the swipe hook and the live region.
- Events to the chrome stay exactly as today (`tier-revealed`, `bank-changed`, `navigation-locked`, `opening-revealing`, `toast`), driven by comparing the state before and after a transition where possible (lock depth crossing 0, bank object replaced).
- Vitest covers every exported transition and derived view of `lib/booster.ts`, and the moved helpers keep their existing tests.
- Code written or rewritten here carries no comments (AGENTS.md), and no planning ids; code moved unchanged may keep its existing doc comments, minus any planning id (story n.n, EXPERIENCE.md, DESIGN.md, AD-n).

**Never:**
- No visible or audible change: markup, classes, `data-*`, labels, announcements, focus order, timings and the opening exchange stay as they are.
- No Stimulus controller, no server markup change, no locale change, no change to `BoostersHelper#booster_props` or the props contract (`lib/booster_props.ts` types stay; new types may be added beside them).
- Do not touch the trade board's code, nor delete any React component (the next entry does); the sub-components (`BoosterCard`, `BoosterCanister`, `BoosterTray`, `BoosterZoom`, `BoosterPlate`, `BoosterBanner`, `BoosterCelebration`, `BoosterPanel`, `BoosterStrip`) change only their import paths.
- No `innerHTML`-family use outside `lib/server_html.ts` (the existing `dangerouslySetInnerHTML` stays).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Start | bank (available 0 / >0), `opened` answer or null, layout, `now`, celebration remembered, Turbo preview | sealed/empty or a dealt hand all revealed past the guard (stored on the phone), restored celebration still, focus open/back (none on preview) | — |
| Opening blocked | opening, reveal, Reveal all or store running; no pack; dealt hand not all revealed | `canOpen` false, state unchanged | — |
| Opening answered | key, answer | bank replaced, counts from `tierCountsBefore`, celebration pending, cards face down, key dropped; deal flags; at end dealt/inventory, unlock, focus card | refused/failed: canister disarmed, sealed or empty, reason, key per `keyAfter`, unlock, focus back when empty; `no_pack_available` empties the bank |
| Reveal | index, from all or not | refused when already revealed/revealing or (not from all) while Reveal all or a Légendaire runs; mark sets revealed, `revealedAt = now`, counts | completes the hand (row, not from all) → status complete, focus open/back, celebration |
| Store (phone) | top card revealed, guard over, nothing running | stored, focus next card or complete | refused otherwise; from Reveal all skips guard and lock checks |
| Layout | width asks another layout while busy | kept pending, applied when idle: stored per `storedAfterRebuild`, complete + celebrate when all revealed, rebuild counter bumped, zoom and banner cleared, focus card if focus was inside | — |
| Bank | countdown zero / owed / fetched | `page` / `bank` / `owe` per `booster_bank.ts`; a fetch answered after a newer bank change is ignored; phase follows the count when sealed/empty | fetch failure: unchanged |
| Lock | nested lock/unlock | depth counted; `locked` true from 1; releasing to 0 lets pending layout and owed bank run | unlock at 0 does nothing |
| Celebration | hand complete with pending tiers | results shown only while no banner plays, announced once; cleared by the next opening | no tiers reached: nothing |
| Zoom | tray slot | opens only when idle and the slot is filled; steps to filled neighbours; close asks focus back on the slot | — |

</intent-contract>

## Code Map

- `app/frontend/components/Booster.tsx` -- the island: all state (lines 172-241), focus (299-333), banner (335-342), celebration (344-369), bank (371-391), opening (393-565), reveal (567-763), phone store/zoom (765-938), layout (940-987), card activation and countdown (989-1028). Becomes the driver. Drop its header comment (planning ids) and inline comments.
- `app/frontend/components/BoosterView.tsx` -- draws `BoosterViewState`; its derivations (`openLabel`, `openDisabled`, `revealAllDisabled`, `busy`, `statusTone`, `hint`, `top`, plate card, zoom neighbours) move into a derived view of the module, which it reads instead.
- `app/frontend/components/useNavigationLock.ts`, `useLiveRegion.ts`, `useIslandTimers.ts`, `useBoosterCountdown.ts`, `useCardSwipe.ts` -- the lock's depth moves into the state (delete `useNavigationLock.ts`; the driver dispatches `navigation-locked` on depth 0↔1 and releases on unmount); the others stay (DOM/timer plumbing).
- `app/frontend/lib/booster.ts` (+ `booster.test.ts`) -- today timings and pure helpers; `git mv` to `lib/booster_motion.ts` (+ test), then a new `lib/booster.ts` holds the state module. Rule helpers a transition or derived view uses (`revealingOpening`, `planRevealAll`, `keyAfter`, `countsAfterReveal`, `layoutFor`, `PHONE_QUERY`, `NARROW_QUERY`, `Layout`, `faceSize`, `topOfPile`, `zoomNeighbour`, `storedAfterRebuild`, `REVEAL_GUARD`) move into the new `booster.ts` with their tests; `formatClock`, `formatDailyClock`, `secondsUntil` move to `lib/booster_clock.ts` (+ test); the rest stays in `booster_motion.ts`.
- Importers to repoint: `controllers/countdown_controller.ts`, `lib/booster_effects.ts`, `lib/booster_keyframes.ts` (+ test), `lib/booster_page.ts`, `lib/booster_bank.ts`, `components/BoosterBanner.tsx`, `BoosterPlate.tsx`, `BoosterCard.tsx`, `BoosterView.tsx`, `useCardSwipe.ts`, `useBoosterCountdown.ts`.
- `app/frontend/lib/booster_bank.ts` -- `atZero`, `owedBankDue`, `phaseForBank`, `handPutAway` stay and are used by the module; `fetchBank` stays (I/O, called by the driver).
- `app/frontend/lib/celebration.ts` -- `celebrationResults`, `restoredCelebration`, `celebrationAnnouncement`; reuse, read-only.
- `app/frontend/lib/booster_props.ts` -- `BoosterPhase`, `BoosterStatus`, `BoosterBank` types; reuse.
- `app/frontend/lib/opening.ts` -- `OpeningAnswer`, `OpeningResult`, `OpeningSetTier`; read-only.
- `app/frontend/lib/trade_board.ts` -- the shape to follow (readonly state, `start`, transitions, derived views, no comments).
- `test/system/booster_test.rb` -- the net; existing tests read-only. Desktop window is 1400×1400 (`SCREEN_SIZE`); the phone test at line 792 shows the VALVE set completed by `common_card_one, uncommon_card_one, rare_card_one, portal_one, common_card_one` and the celebration selector; helpers `assert_announced`, `announcements`, `open_screen(…, more:)`.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/booster_motion.ts`, `booster_clock.ts` (+ tests) -- `git mv` the current `booster.ts`/`booster.test.ts` to `booster_motion*`, split out the clock and the rule helpers listed in the Code Map, repoint importers -- frees `booster.ts` for the state module.
- [x] `app/frontend/lib/booster.ts` -- `BoosterState`, `start`, transitions and derived views per Design Notes.
- [x] `app/frontend/lib/booster.test.ts` -- one `describe` per transition and derived view, covering the I/O matrix rows (including refusals that return the same state).
- [x] `app/frontend/components/Booster.tsx` -- rewrite as the driver per Design Notes; delete `useNavigationLock.ts`.
- [x] `app/frontend/components/BoosterView.tsx` -- read the module's state and derived view instead of its own derivations; markup output unchanged.
- [x] `test/system/booster_test.rb` -- add, after the existing tests: (1) on the wide layout, a hand completing VALVE revealed card by card shows no `.booster-celebration` until the last reveal, then `.booster__info .booster-celebration` with `SET COMPLETE` and `VALVE`, announced once (`Set complete: …`), state INVENTORY COMPLETE; its banner link leads to the set's page; `page.go_back` shows the hand face up with `.booster__info .booster-celebration[data-still]` and no new announcement of it; "Open the next one" removes it. (2) on the wide layout, Reveal all on a hand completing a set with a Légendaire: a MutationObserver installed before Reveal all records that `.booster-banner` and `.booster-celebration` are never in the DOM together, and the celebration appears once the banner is gone. Use retrying matchers only.

**Acceptance Criteria:**
- Given the branch, when `bin/rails test test/system/booster_test.rb` runs, then every test passes, and `git diff d00573be -- test/system/booster_test.rb` contains only added lines.
- Given `lib/booster.ts`, when `rtk proxy grep -nE "window|document|performance|matchMedia|fetch\(|setTimeout|crypto|location|from \"react" app/frontend/lib/booster.ts` runs, then nothing matches.
- Given `Booster.tsx`, when grepped for `useState`, then exactly one state hook remains for the module state (plus any view-local hook state inside reused hooks), and no `useRef` holds a state field.
- Given `npm run test:js`, then `booster.test.ts` exercises every exported function of `lib/booster.ts`.

## Implementation Notes

- Built by a coding subagent from this plan; every Execution task landed. `lib/booster.ts` holds `BoosterState`, `start`, the transitions and the derived views (`controls`, `focusTarget`, `shownCelebration`, `celebrationToAnnounce`, `activation`, `idle`, `canOpen`/`canReveal`/`canRevealAll`/`canStore`, `revealAllPlan`, `countdownAtZero`, `bankDue`); `Booster.tsx` keeps one `useState` plus the `current` ref mirroring it, applies transitions through `apply`, and dispatches `bank-changed` and `navigation-locked` from `reflect(before, after)`.
- Names differ from the indicative ones where a field already had the name: `resultHeadShown` (field `headShown`), `celebrationSpoken` (field `celebrationAnnounced`), `bankFetchOwed` (field `bankOwed`), `bankDue` (to avoid shadowing `owedBankDue` from `booster_bank.ts`); `lockReleased` added for the unmount release; no standalone `focusAsked`: every focus request is part of the transition that asks it.
- Rules moved into the module beyond the Code Map's list: `CLICK_AFTER_DRAG` (used by `activation`, which takes the swipe's last drag end as an argument) and "no banner on the phone" (inside `bannerShown`).
- The `Banner` type moved to `lib/booster.ts`; `BoosterBanner.tsx` imports it instead of declaring it (its only change besides the import path).
- System test (2) watches `.booster__banner`, the banner's real class; the plan's `.booster-banner` matches nothing.

- After review: `apply(transition)` renders normally and `commit(transition)` renders at once (`flushSync`) where the faces must be in the DOM (answer, deal, store, retract); the opening key is taken once; the unmount releases the lock on `current` and dispatches `navigation-locked: false` itself; the `Focus` type has no `"after"` variant; the state's arrays are `readonly`, which widens the prop types of `BoosterTray.tsx` (`stored`) and `BoosterCelebration.tsx` (`results`) besides `pileDepth` and `handPutAway`.
- A third system test was added at review: the countdown's zero while the hand is dealt, the reserve fetched once every card is revealed.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 22 findings — high 0, medium 1, low 12, false 8, maybe-false 1
- findings:
  - `[low]` `[reject]` (blind) Some transitions (`arming`, `ejecting`, `openingEnded`, `legendarySignalled`, `legendaryEnded`, `revealAllEnded`, `storeEnded`, `revealEnded` with an index not revealing) return a new object without a change — the driver never calls them where they change nothing (each runs once per step of its sequence), so no extra render or repeated `completed` happens; the fix is a guard per transition for a call that does not occur.
  - `[low]` `[defer]` (blind) `controls().revealAllDisabled` (`legendary !== null`) disagrees with `canRevealAll` (`legendaryRunning`): "Reveal all" looks enabled during a Légendaire's hold and does nothing — the island had the same split before this change; fixing it is a visible change, deferred to the Stimulus view.
  - `[low]` `[patch]` (blind) `open()` makes a UUID on every opening and its `?? newKey()` fallback would send a key the state does not hold — the key is taken once (kept key or a new one), passed to `arming` and sent.
  - `[low]` `[patch]` (blind) `apply(transition, true)` hides why some steps commit at once — a named `commit` replaces the boolean.
  - `[low]` `[patch]` (blind) `Focus` keeps a dead `"after"` variant and a test feeding it — dropped.
  - `[low]` `[patch]` (blind) `BoosterState` arrays are mutable through the type, unlike `trade_board.ts` — made `readonly`, helper parameters widened.
  - `[false]` `[reject]` (blind) `lib/booster.ts` imports from `booster_bank.ts`, which does network I/O, and the two import each other — the imported functions are pure; `booster_bank.ts` imports only `type Layout` back (erased); the plan's Code Map keeps these rules in `booster_bank.ts` for the module to use.
  - `[low]` `[patch]` (blind) The unmount cleanup goes through `apply`/`reflect` and could run `whenIdle` (layout rebuild, bank fetch) on an unmounting island if hooks were reordered — the cleanup now releases the lock on `current` and dispatches `navigation-locked: false` itself.
  - `[maybe-false]` `[reject]` (blind) `retracted` keeps `zoom`, `banner`, `legendary`, `counts`, `reason` — the island's `retract` reset the same fields; whether a zoom or banner can be open when "Open the next one" runs needs a browser check of the zoom's modality; if true it is low (the view guards a zoom index past the cards), and it predates the change.
  - `[low]` `[patch]` (blind) Moved `booster_motion.ts` and its test keep prototype/planning references and a test named "match the plan's values" — removed and renamed. The touched components' (`BoosterCard`, `BoosterPlate`, `useCardSwipe`) old `story 8.12`/`EXPERIENCE.md` comments are pre-existing in files the next entry deletes; left.
  - `[low]` `[patch]` (blind) `booster_motion.test.ts` imports `DEAL_STAGGER` twice and has a stray blank line — cleaned.
  - `[false]` `[reject]` (blind) No test holds "cards go by position, never by slug" — every transition is index-based, and the system tests deal duplicate cards (`common_card_one` twice at line 794, `rare_card_one` ×5 in the zoom tests) through reveal, store and zoom.
  - `[false]` `[reject]` (blind) New system tests cover only the wide layout; phone completion, a layout change while busy and the refusal are not exercised — existing `booster_test.rb` tests run each (phone Reveal all at 1022, width change during a reveal at 1124, refusal at 462); the never-disconnected observer dies with the page.
  - `[low]` `[defer]` (edge) `revealAllDisabled` vs `canRevealAll`: "Reveal all" enabled but inert during a Légendaire's hold — same root cause as the blind row; grouped and deferred with it.
  - `[false]` `[reject]` (edge) Phone Reveal all on an empty `stored` never completes — an opened pack always holds 3 or 5 cards (the opening exchange), so `stored` is never empty when Reveal all runs.
  - `[false]` `[reject]` (edge) The celebration test never checks that going back announces nothing — the live region keeps its spans, and the test's last assertion (after "Open the next one", which announces nothing) finds no `Set complete:` span, so a re-announcement on return would fail it.
  - `[low]` `[patch]` (edge) The celebration test's "no celebration yet" check runs mid-reveal — it now waits for the navigation to unlock (the reveal's end) first.
  - `[medium]` `[patch]` (verification-gap) The owed bank fetch (countdown zero while dealt, fetched once the hand is put away) is never run end to end — system test added: the countdown passes zero while dealt, every card is revealed, the reserve shows 1 capsule, the chip 1 and "Open the next one" is enabled.
  - `[low]` `[reject]` (verification-gap) The unmount lock release is not observable by the "leaving during Reveal all" test — `navigation_lock_controller` clears the lock on its own disconnect; redundant coverage, no shipped risk.
  - `[false]` `[reject]` (intent) The choreography (open, reveal, Reveal all, store sequences) stays in `Booster.tsx`, so the next entry re-codes it — AD-16 keeps the state module free of the DOM and AD-30 has the root controller "run every multi-step sequence"; the sequences animate elements, so they belong to the view side, and entry 3 ("a `booster` root controller driving `lib/booster.ts`") ports them by design.
  - `[false]` `[reject]` (intent) The module is a single state record, not loose helpers like the trade board's — `trade_board.ts` is also one readonly `BoardState` with `start`, transitions and derived views (`pickerView`, `changed`, `sendable`).
  - `[false]` `[reject]` (intent) The added system tests cover only the celebration — the intent names the desktop celebration as the net's gap; every other path keeps its existing tests, all passing.

## Design Notes

**State** (field names indicative): `bank`, `bankGeneration`, `bankOwed`, `phase`, `status`, `opening` (a request or retract running), `pendingKey`, `answer`, `revealed`, `revealedAt`, `revealing` (indices), `legendary` (index shown) and `legendaryRunning`, `revealingAll`, `storing`, `stored`, `counts`, `dealt`, `armed`, `headShown`, `canisterAway`, `docks`, `reason`, `banner` (`{ key, tier, large, line, reduced }`) and `bannerKey`, `layout`, `pendingLayout`, `rebuilds`, `zoom`, `celebrationPending`, `celebration`, `celebrationStill`, `celebrationAnnounced`, `lockDepth`, `focus` (`"open" | "back" | "card" | { slot }` or null).

**Transitions** (one per step of today's code, names indicative): `start`; `lock`, `unlock`; `canOpen`, `openingStarted`, `retracted`, `arming`, `openingRefused`, `openingAnswered`, `ejecting`, `headShown`, `cardsDealt`, `openingEnded`; `canReveal`, `revealStarted`, `revealMarked(now)`, `legendarySignalled`, `legendaryEnded`, `revealEnded`, `revealAllPlan`, `revealAllStarted`, `revealAllEnded`; `canStore(now)`, `storeStarted`, `cardStored`, `storeEnded`; `layoutAsked`, `layoutApplied(focusedInside)`; `bannerShown`, `bannerEnded(key)`; `celebrate`, `celebrationAnnounced`; `bankChanged`, `bankFetched(bank, generation)`, `countdownAtZero` (returns `page|bank|owe`), `bankOwed`, `owedBankDue`, `owedBankTaken`; `zoomOpened`, `zoomClosed`, `zoomStepped`; `focusGiven`; `idle`. Derived: `controls(state)` (open variant `open|next|empty`, open disabled/busy, Reveal all disabled, status tone, hint variant and count, pile top, plate index, zoom neighbours), `focusTarget(state)` resolving `"card"` to an index or the after-target, `shownCelebration(state)`, `activation(state, index, now)` (`reveal | store | leave | none`).

**Driver** -- one state, transitions applied in order; `flushSync` where today's code needs the DOM committed (faces in, deal, store, retract):
```ts
const current = useRef(start(init))
const [state, setState] = useState(current.current)
const apply = (transition: (s: BoosterState) => BoosterState, sync = false) => {
  const before = current.current
  const after = transition(before)
  if (after === before) return after
  current.current = after
  if (sync) flushSync(() => setState(after)); else setState(after)
  reflect(before, after) // navigation-locked on depth 0↔1, bank-changed when bank replaced, whenIdle on unlock to 0
  return after
}
```

## Verification

**Environment:** run every command from `/home/teyermann/projets/gameble/.claude/worktrees/epic-port-off-react`; export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react CHROME_BIN=/usr/bin/chromium` for every Rails command; run system test files one at a time; do not commit, push or run `script/github_board/sync.py`; if a test run rewrites `db/schema.rb`, `git checkout db/schema.rb`.

**Commands:**
- `bin/rails test test/system/booster_test.rb` -- all pass (run it at least three times; a random failure is a defect).
- `bin/rails test test/system/live_updates_test.rb test/system/navigation_lock_test.rb` (if present) and any other system file whose name or content mentions the booster (`rtk proxy grep -ln "booster" test/system`), one file at a time -- all pass.
- `bin/rails test` -- all pass.
- `npm run test:js`, `npm run typecheck` -- pass.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `script/check_markup_apis` -- clean.

## Auto Run Result

**Summary:** the booster's state leaves React. `lib/booster.ts` is now the screen's DOM-free state module: one readonly `BoosterState`, `start`, pure transitions for the opening (start, retract, arm, refusal, answer, deal, end), the reveal and Reveal all, the phone's store, the layout (asked, applied when idle), the banner, the celebration (pending, shown while no banner plays, announced once), the bank (changed, fetched with a generation check, owed, due), the navigation lock (counted depth), the zoom and the focus, and derived views (`controls`, `focusTarget`, `shownCelebration`, `activation`, `idle`, `can*`). `Booster.tsx` holds that one state, applies transitions, runs the choreography and dispatches the chrome's events from the state before and after each transition; `BoosterView` draws from the state and `controls()`. The module's former content moved to `lib/booster_motion.ts` (timings, keyframe geometry, pile poses) and `lib/booster_clock.ts` (countdown formatting). Three system tests were added as the net for the view swap.

**Files changed:**
- `app/frontend/lib/booster.ts` (+ test) — the state module and its Vitest suite (one `describe` per transition or derived view).
- `app/frontend/lib/booster_motion.ts` (+ test) — the former `booster.ts`, moved by `git mv`, rule helpers and clocks taken out, prototype references removed.
- `app/frontend/lib/booster_clock.ts` (+ test) — `formatClock`, `formatDailyClock`, `secondsUntil`.
- `app/frontend/components/Booster.tsx` — the driver: one state, `apply`/`commit`, `reflect`, the sequences; `useNavigationLock.ts` deleted.
- `app/frontend/components/BoosterView.tsx` — reads the state and `controls()`; markup unchanged.
- `BoosterBanner.tsx`, `BoosterCard.tsx`, `BoosterPlate.tsx`, `BoosterTray.tsx`, `BoosterCelebration.tsx`, `useCardSwipe.ts`, `useBoosterCountdown.ts`, `controllers/countdown_controller.ts`, `lib/booster_effects.ts`, `lib/booster_keyframes.ts` (+ test), `lib/booster_bank.ts` — import paths, the `Banner` type's move, readonly parameter types.
- `test/system/booster_test.rb` — three tests appended (wide-layout celebration card by card and back from its album; Reveal all with a Légendaire never showing banner and celebration together; the owed reserve fetched once the hand is revealed); no existing line changed.

**Review:** 22 findings (medium 1, low 12, false 8, maybe-false 1). Patched: the owed bank fetch untested end to end (medium, system test added), the opening key made once, a named `commit` for synchronous renders, the unmount lock release independent of hook order, the dead `"after"` focus, readonly state arrays, prototype references and clutter in `booster_motion*`, the celebration test waiting for each reveal's end. Deferred: "Reveal all" enabled but inert during a Légendaire's hold (pre-existing split; fixing it is a visible change). Rejected: no-op transitions returning new objects (never called that way), `booster_bank` import (pure helpers, type-only cycle), `retracted` partial reset (pre-existing, unverified), position-not-slug test (covered by duplicate-card system tests), wider system coverage (existing tests), empty stored hand (unreachable), go-back announcement (already caught), unmount release observability (navigation lock controller clears itself), choreography left in the view (AD-16 keeps the module DOM-free, AD-30 puts sequences in the root controller), module shape (trade board's is also one state record), net scope (the intent names the celebration).

**Follow-up review recommended: false** (patched by verdict: high 0, medium 1, low 9).

**Verification:**
- `bin/rails test`: 3201 runs, 0 failures, 0 errors (after the review patches).
- `bin/rails test test/system/booster_test.rb`: 43 runs, 0 failures, three consecutive runs after the patches (four more green runs by the implementer before them); `git diff d00573be -- test/system/booster_test.rb` removes no line.
- One at a time, green: `shell`, `card_preview`, `countdown`, `hub`, `settings`, `daily_bonus`, `live_updates` system tests.
- `npm run test:js` 59 files, 679 tests; `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `i18n-tasks missing`/`unused`, `script/check_markup_apis` clean.
- `lib/booster.ts` holds no DOM, clock, network or React word (acceptance grep empty); `Booster.tsx` has one `useState`.

**Residual risks:** the choreography still lives in `Booster.tsx` and will be ported into the `booster` root controller by the next entry; no visual check at phone width or with motion beyond the system tests; the new countdown test, like the existing one it copies, sleeps past a real countdown.
