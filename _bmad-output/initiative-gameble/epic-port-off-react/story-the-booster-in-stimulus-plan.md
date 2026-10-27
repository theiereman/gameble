---
title: 'The booster in Stimulus'
type: 'refactor'
ticket: '3'
created: '2026-10-26'
status: 'built'
baseline_revision: '626e1fea619aaa9056d537b30f45222a544b1aaa'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-port-off-react/story-the-trade-board-in-stimulus-plan.md'
  - '{project-root}/_bmad-output/initiative-gameble/epic-port-off-react/story-the-booster-s-state-leaves-react-plan.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A throw inside a running sequence (opening, reveal, store) would leave the navigation lock held until the player leaves, now that no error boundary wraps the screen.
    evidence: |-
      Every sequence starts with `void this.openBooster()`, `void this.reveal(...)` or `void this.store(...)` and has no catch or finally; a throw after `apply(lock)` keeps `lockDepth > 0`, so `gameble:navigation-locked: true` stays. No reachable throw was shown: the state is set in `connect()` before any handler runs, and `apply()` returns the kept state once disposed. Settle it by finding a DOM or data path inside a sequence that can throw (a missing card part, a malformed answer passing `isAnswer`).
    location: >-
      app/frontend/controllers/booster_controller.ts openBooster / reveal / store
    severity: medium (unverified)
  - summary: >-
      Two browser-only copy branches are not checked: the phone plate band's closing hint ("Capsule inventoried · +5 cards…") and the live canister label without a published season.
    evidence: |-
      `.booster-plate-band__hint` is asserted only for "Tap the card to reveal it" (booster_test.rb), and no system test runs without a published season; the controller test reads the server's canister label, which the root rewrites on connect. Mapping the phone's `done` hint wrongly or flipping `season > 0` in the root fails no test.
    location: >-
      app/frontend/controllers/booster_plate_controller.ts, app/frontend/controllers/booster_controller.ts canister label
    severity: low
---

<intent-contract>

## Intent

**Problem:** The booster is the last React island: `Booster.tsx` runs the choreography, `BoosterView.tsx` and nine sub-components draw it, and Turbo Mount ships every URL, word, icon and an opened pack as one JSON props value. That breaks AD-16, AD-18 and AD-30, and blocks removing React (next entry).

**Approach:** Render the whole screen on the server as one tree holding the three layouts (wide, narrow, phone), with fixed copy in every variant, run-time templates under `booster.strings`, and everything that appears later as server `<template>`s (card slot, face per size, tray slots, plate, banner, celebration parts, live-region line, rarity icons). A `booster` root controller holds `lib/booster.ts`'s state, applies every transition, runs every sequence ported from `Booster.tsx` and drives child controllers per region through outlets; card faces from the opening exchange go through `serverTemplate()`. Then delete the island, its components and hooks, and its Turbo Mount registration.

## Boundaries & Constraints

**Always:**
- `test/system/booster_test.rb` passes, and `git diff 626e1fea -- test/system/booster_test.rb` holds only: `boosters.island.*` keys renamed to their new scope; the code-loading failure test replaced by a no-JavaScript form test; the six `.booster__counter` text assertions (lines 153, 191, 201, 433, 1119, 1177) removed, because the ticket's note drops the "n / 5" counter. Every other system test file mentioning the booster (`shell`, `card_preview`, `countdown`, `hub`, `settings`, `daily_bonus`, `live_updates`) passes unchanged.
- No visible or audible change other than the counter's removal: classes, `data-*`, labels, announcements, focus order, timings, keyframes, the opening exchange and its JSON stay as they are. The deferred "Reveal all looks enabled during a Légendaire's hold" stays exactly as today.
- AD-30 anatomy as the trade board set it: root `booster` (exported named class) alone holds the state from `lib/booster.ts`, applies transitions, runs sequences, writes `data-layout` (only when the module says idle), `data-phase`, `data-status` and its other state on its own element, composes run-time strings with `t()` from its `strings` Object value, owns the live region and focus. Children `booster-<part>` write only inside their region, report intents with `this.dispatch(…, { cancelable: true })` caught by `data-action` on the root (routes listed once in a helper constant like `TradesHelper::BOARD_ACTIONS`), never reference each other, and are driven through the root's outlets (selectors scoped to `#booster`, optional ones checked with `has…Outlet`, none kept past disconnect).
- Initial state from markup: scalar Stimulus values and `data-*` on targets; the `strings` value carries templates only.
- Copy per AD-18: a fixed string the screen switches between (state words, open-button labels, hints without a count, card label "? ? ?" vs tier) is rendered in every variant and shown by CSS from a `data-*`; only strings that take a value at run time or travel in a toast, an announcement or an `aria-label` are composed from `booster.strings`.
- No `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `DOMParser` or `createContextualFragment` outside `lib/server_html.ts`; script creates only decorative `aria-hidden` nodes (sparks, rings, notches, glosses, glints, celebration sparks) and canvases; everything else is cloned from server `<template>`s or moved. Server HTML carries no `style` attribute (custom properties and pile poses set by script). No database id in markup.
- Every string in `en.yml` and `fr.yml` (French plurals keep `zero`); code carries no comments but one-line external constraints, and no planning ids.

**Never:**
- No feature, no new endpoint, no change to `PacksHelper#pack_opening_json`'s JSON or `BoostersHelper#booster_bank` (the screen's JSON answer).
- No React, Turbo Mount or React toolchain removal from `package.json`, Vite config, CSP or layouts (next entry); only the booster's usage goes.
- No `gameble:*` event for the screen's own traffic; the chrome's events (`tier-revealed`, `bank-changed`, `navigation-locked`, `opening-revealing`, `toast`) stay exactly as dispatched today.
- Do not touch the trade board's code nor any test outside the booster's except `test/controllers/boosters_controller_test.rb`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Page drawn | bank >0 / 0, season or none, layout from width | sealed canister or empty reserve with next time; panel (wide/narrow) or strip (phone); focus Open or Back; fallback hidden | without JS: tree hidden, fallback form shown |
| Opening | canister or Open | lock, arm, POST with key, deal face down (pile on phone), INVENTORY, focus first card | refused/throttled/failed/stale CSRF: reason inline, toast, announced, key kept per `keyAfter` |
| Reveal / Reveal all | card activation, Reveal all | tier sequence, announcement, rarity counter event, Légendaire held, one summary | activation inside the guard ignored |
| Phone store / zoom | Store, tap, swipe; filled slot | card leaves pile to tray, focus next; zoom dialog steps ◀ ▶ / swipe, Esc returns focus to slot, See the card leaves | short drag springs back; tilt is never a swipe |
| Layout change | width crosses 720/900 | applied only when idle; same hand redrawn at the new face size, revealed cards stored on phone | — |
| Celebration | hand completes a set | shown after last reveal and no banner, announced once, still after Back from its album | — |
| Countdown / bank | next booster arrives | refresh page (sealed/empty), refetch bank, or owe until hand put away | fetch failure: unchanged |
| Opened pack | `?pack=<token>` | hand dealt face up, celebration still when marked | foreign/unknown token: canister |
| Leaving | Turbo visit away mid-sequence | sequence stops, lock released, no late events | — |

</intent-contract>

## Code Map

- `app/frontend/components/Booster.tsx` (driver: sequences `retract`, `blowAndDeal`, `fadeAndDeal`, `open`, `artReady`, `mark`, `revealTier`, `revealLegendary`, `revealStill`, `reveal`, `revealAll`, `revealAndStoreAll`, `store`, `springBack`, swipe wiring, `whenIdle`, `refuse`, `refreshBank`, `reflect`, focus effect, matchMedia effect, countdown at zero, `leaveFor`, `repost`, `leaveForAlbum`, `guardBack`) -- the behaviour to port into the root line by line, then delete.
- `app/frontend/components/BoosterView.tsx`, `BoosterCard.tsx`, `BoosterCanister.tsx`, `BoosterPanel.tsx`, `BoosterStrip.tsx`, `BoosterPlate.tsx` (plate pop keyframes inline), `BoosterTray.tsx` (`drawCardArt` 22×30 with `artPalette`), `BoosterZoom.tsx` (showModal, focus See the card, scrim click, touch swipe via `swipeStep`, repost status), `BoosterBanner.tsx`, `BoosterCelebration.tsx` (results list, folded banner, ticks, sparks, phone stepping) -- the exact markup (classes, attributes, aria, order) the server must render and the view logic to port; then delete with `BoosterErrorBoundary.tsx`.
- `app/frontend/components/useCardSwipe.ts`, `useBoosterCountdown.ts`, `useIslandTimers.ts`, `useLiveRegion.ts` -- port to `lib/booster_*.ts` helpers (DOM-free where possible) or into controllers; delete. `app/frontend/components/` must be gone.
- `app/frontend/entrypoints/application.ts` -- drop TurboMount, React imports, `BoosterErrorBoundary`, the `Booster` registration and the header's island mention.
- `app/frontend/lib/booster.ts` (+test) -- state module, reused; drop `Controls.revealedCount`; add the phone celebration's shown result (`celebrationStepped`) if the step moves into the state; keep everything else. `lib/booster_props.ts` -- keep the types the module uses (`BoosterBank`, `BoosterPhase`, `BoosterStatus`) by moving them into `lib/booster.ts` (or a `lib/booster_*.ts`), drop `BoosterProps`/`BoosterStrings`, delete the file; repoint importers.
- Reused unchanged: `lib/booster_motion.ts`, `booster_keyframes.ts`, `booster_effects.ts`, `booster_bank.ts` (`fetchBank`), `booster_clock.ts`, `booster_page.ts`, `celebration.ts`, `opening.ts`, `repost.ts`, `swipe.ts`, `i18n.ts` (`t`, `formatNumber`), `motion.ts`, `local_time.ts`, `events.ts`, `server_html.ts`, `card_art` (`drawCardArt`).
- `app/frontend/controllers/trade_board_controller.ts` and its children, `app/helpers/trades_helper.rb` (`BOARD_ACTIONS`, `trade_board_strings`) -- the conventions to copy.
- `app/views/boosters/show.html.erb` -- becomes the tree plus the fallback; new partials under `app/views/boosters/`.
- `app/helpers/boosters_helper.rb` -- `booster_props` and its private icon helpers go; keep `booster_bank`; add `BOOSTER_ACTIONS`, root data/values, `booster_strings` (from `booster.strings`), per-card data for an opened pack. `app/helpers/packs_helper.rb:59` reads `boosters.island.card_label` -- repoint to the new key.
- `app/controllers/boosters_controller.rb` -- may expose the opened pack and its cards (`opened_pack` via `Game::OpenedPackByToken`, `cards_of`, `pack_set_tiers`) to the view instead of the JSON hash; stays read-only, JSON format unchanged.
- `app/frontend/styles/booster.css`, `booster-layouts.css` -- rules assume React drew only the current layout: add hiding per `data-layout`, the fallback rule (`.booster-island:has(...)` at booster.css:40) rewritten, `.booster__counter` rules removed, header comments de-islanded; every drawn state must look as today.
- `config/locales/en.yml:536-657`, `fr.yml` (same block, ~1007) -- `boosters.island.*` splits into `booster.*` (fixed words) and `booster.strings.*` (run-time templates, `celebration` group whole); `revealed_count`, `island_failed`, `reload` go; `boosters.show.title` stays. `config/i18n-tasks.yml:33-34` -- ignore `booster.strings.*` instead of `boosters.island.*`.
- `test/controllers/boosters_controller_test.rb` -- the props tests (`ISLAND`, `props`) rewritten against the markup. `test/controllers/packs_controller_test.rb` `ISLAND` stays as is.
- `test/system/booster_test.rb` -- the net; changes only as Always says.

## Tasks & Acceptance

**Execution:**
- [x] `app/views/boosters/show.html.erb` + partials (`_booster`, `_info`, `_strip`, `_actions`, `_canister`, `_stage`, `_plate`, `_tray`, `_zoom`, `_celebration`, `_opened`, card/slot templates) -- server tree per Design Notes; fallback form after the root, hidden once the root has drawn.
- [x] `app/helpers/boosters_helper.rb`, `app/helpers/packs_helper.rb`, `app/controllers/boosters_controller.rb` -- markup data per Design Notes; `booster_bank` and the JSON answer unchanged.
- [x] `config/locales/en.yml`, `fr.yml`, `config/i18n-tasks.yml` -- new scopes; `i18n-tasks missing` and `unused` clean.
- [x] `app/frontend/controllers/booster_controller.ts` (root) and `booster_*_controller.ts` children -- per Design Notes, porting every sequence and view rule of the island.
- [x] `app/frontend/lib/booster.ts` (+test), `lib/booster_*.ts` helpers (+tests) -- timers, swipe tracking, countdown ticking and markup readers moved out of the hooks; DOM-free logic tested in Vitest (node environment); `booster_props.ts` removed.
- [x] `app/frontend/entrypoints/application.ts`, delete `app/frontend/components/` -- no React import left in `app/frontend`.
- [x] `app/frontend/styles/booster.css`, `booster-layouts.css` -- one tree drawn per `data-layout`, identical states.
- [x] `test/controllers/boosters_controller_test.rb` -- rewrite the props tests against markup: root values (open/card/repost/bank URLs, delimiter, pack size, bank values, season), `strings` value keys equal `booster.strings` keys camelized with the samples the old test checked, rarity templates per tier with names and `booster-card__label-icon` icons, celebration icon templates (next, arrow, check, five rank marks), zoom arrows, opened pack's card data, face templates s/m/xl and set tiers, no `[style]`, no database id, fallback form and link; keep every other assertion (top bar, chip, cache control, JSON, visitor).
- [x] `test/system/booster_test.rb` -- the three changes Always allows; the replacement test: with script execution disabled (`Emulation.setScriptExecutionDisabled`), `/en/booster` shows `.booster__fallback` with OPEN THE CAPSULE and no visible `.booster`; pressing it lands on the opened pack's page; scripts re-enabled in `ensure`.

**Acceptance Criteria:**
- Given the branch, when `bin/rails test test/system/booster_test.rb` runs three times in a row, then every test passes each time and the file's diff from `626e1fea` holds only the allowed changes.
- Given the repo, when `rtk proxy grep -rn -e "from \"react" -e "turbo-mount" -e "turbo_mount" -e "booster_props" -e "boosters\.island" app config test` runs, then nothing matches but `test/controllers/packs_controller_test.rb`'s `ISLAND` constant, and `app/frontend/components` does not exist.
- Given `npm run test:js`, then `lib/booster.ts` and every new `lib/booster_*.ts` helper are covered and pass.
- Given `script/check_markup_apis`, then it passes.

## Implementation Notes

- Built by a coding subagent from this plan; every Execution task landed. Root `booster` (named export plus default) holds the state and runs every sequence ported from `Booster.tsx`; eight children (`booster-info` ×2, `booster-actions`, `booster-canister`, `booster-stage`, `booster-plate`, `booster-tray`, `booster-zoom`, `booster-celebration` ×2) report intents routed by `BoostersHelper::BOOSTER_ACTIONS`; outlets scoped to `#booster`. The stage owns the card slots (no per-card controller); the canister is a `<template>` cloned again on each dock.
- New DOM-free helpers with Vitest tests: `lib/booster_timers.ts`, `booster_swipe.ts`, `booster_countdown.ts`, `booster_markup.ts` (markup readers, `openedFrom`), `booster_templates.ts` (happy-dom test). `lib/booster.ts` took `BoosterBank`/`BoosterPhase`/`BoosterStatus`, dropped `Controls.revealedCount` and gained the phone celebration's step (`celebrationSteps`, `celebrationStepped`, `shownResult`).
- The section's `aria-labelledby` is written by the root per layout (`booster-title` on the phone strip, `booster-panel-title` on the panel); the fallback hides once the root writes `data-layout`; a broad `.booster [hidden] { display: none !important }` replaces per-element `[hidden]` rules.
- Focus and the celebration announcement run in a microtask after each render, standing in for React's after-render effect.
- The no-JavaScript test uses `page.visit`: the test case's `visit` waits for Turbo stream sources to connect, which needs scripts.
- Open-button labels are three spans shown by CSS from `data-open`; Capybara's button locator also reads hidden text, so `assert_button "Open the next one"` now matches whichever label shows (weaker, never failing).
- Packwerk's ERB parser rejects a trailing shorthand-keyword `render`, so those renders are parenthesized.
- The acceptance grep also matches `test/controllers/back_office/cards_controller_test.rb:32`, a pre-existing negative assertion (no card-preview island); left, as the plan forbids touching tests outside the booster's.
- After review: `PacksHelper#pack_card_fields` feeds both the opening exchange and the opened-pack markup; celebration parts are found by class; comments elsewhere no longer speak of the island (`app/views/layouts/application.html.erb:4` left for the next entry); `test/system/booster_screen_test.rb` added (faces after `?pack=`, two and four celebration results, the reserve's next line and full flag, `aria-labelledby` per layout).

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 31 findings — high 0, medium 5, low 18, false 6, maybe-false 2
- findings:
  - `[low]` `[patch]` (blind) "Island"/"props" wording left in comments of files around the booster (packs helper and controller, shell views, chrome controllers, lib headers) — reworded to the booster screen / its root controller, plus `config/routes.rb:24`; `booster_test.rb` comments left so its diff keeps only the allowed changes.
  - `[low]` `[patch]` (blind) `BOOSTER_STATUSES` and `CelebrationIcons` exported and unused — deleted.
  - `[low]` `[reject]` (blind) Status list in Ruby, TS and CSS, `RESERVE_PIPS` twice, redundant clamp — inherent to AD-18's server variants shown by CSS (the trade board does the same); no caller diverges today, and a checker adds machinery for a rare edit.
  - `[low]` `[patch]` (blind) `?pack=` path copies the exchange's card fields by hand — `PacksHelper#pack_card_fields` now feeds both; `pack_opening_json` output unchanged.
  - `[low]` `[patch]` (blind) Celebration controller finds parts by position (`childNodes` destructuring, anonymous spans) — parts carry classes and are found by class.
  - `[low]` `[patch]` (blind) Rewritten CSS header comments lost their ` * ` alignment — restored.
  - `[low]` `[reject]` (blind) The whole screen re-renders each countdown second — every child render is idempotent (tray fills once per slot, stage diffs attributes); the island re-rendered its whole view each tick too; no harm shown.
  - `[maybe-false]` `[defer]` (blind) No error boundary: a throw in a sequence leaves the lock held; `apply()` returns undefined without state — the second half is false (state is set in `connect()`, and once disposed `apply()` returns the kept state); no reachable throw shown; deferred as medium (unverified).
  - `[low]` `[patch]` (blind) Controllers have no unit tests and `BOOSTER_ACTIONS` names are unchecked — every route but `stepCelebration` is driven by `booster_test.rb`; grouped with the multi-result celebration gap, whose new system test drives `stepCelebration`; controller unit tests not added (the trade board's convention).
  - `[medium]` `[patch]` (blind) Controller test gaps: `booster-info` outlet, set tier fields, fixed phone words, folded strings — grouped with the vacuous set tier check (patched) and the palette assertion (patched); fixed words are asserted by the system tests and the strings keys by the keys equality.
  - `[low]` `[reject]` (blind) `legendary_signal` twice in the locales, `folded_hint` shipped in strings though server-rendered — the state word is a fixed variant and the announcement a run-time string (AD-18 splits them); the plan keeps `CelebrationStrings` whole for `celebration.ts`.
  - `[low]` `[reject]` (blind) `.booster [hidden] { display: none !important }` too broad — `hidden` means hidden everywhere it is set, faces included; no element is shown while carrying it; scoping it per element adds rules for no named harm.
  - `[low]` `[reject]` (blind) A repost in flight toasts after leaving — the island dispatched the same toast without a disposal check; the toast reports a repost that did happen; changing it is a behaviour change the port forbids.
  - `[false]` `[reject]` (blind) Markup readers turn bad data into a common card / 0 — the data attributes are rendered by the server from `Catalog::Rarity` tiers and integers; no path feeds them other values.
  - `[false]` `[reject]` (edge) Reconnect of the same controller while a bank fetch is in flight — the booster page has no live refresh, is never cached by Turbo and never moves its root; a visit replaces it with a new element and a new controller.
  - `[false]` `[reject]` (edge) Reconnect keeps `bannerKey`, `left`, `afterRenderQueued` — same refutation: the instance never reconnects.
  - `[false]` `[reject]` (edge) Zoom without `showModal` refocuses every render — `allow_browser :modern` serves only browsers with `HTMLDialogElement.showModal`.
  - `[maybe-false]` `[defer]` (edge) A child render that throws leaves the screen half drawn with the fallback hidden — same root cause as the boundary row; grouped and deferred with it.
  - `[low]` `[reject]` (edge) The acceptance grep also matches `back_office/cards_controller_test.rb:32` — a pre-existing negative assertion on a card-preview island; the fix would edit this plan's criterion or a test outside the booster's.
  - `[medium]` `[patch]` (verification-gap) The controller test's `setTier` check iterates an empty list — the opened pack now carries set tier rows (ranked and metal themes) and every `data-*` of each target is asserted after `refute_empty`.
  - `[medium]` `[patch]` (verification-gap) Faces of a hand shown again with `?pack=` never checked in a browser — `booster_screen_test.rb` asserts a `card--m` front on each card and the zoom's `card--xl` face on the phone.
  - `[medium]` `[patch]` (verification-gap) Celebrations with several results, the folded banner and phone stepping never rendered — `booster_screen_test.rb` seeds two and four results and drives "Next result".
  - `[medium]` `[patch]` (verification-gap) The reserve's "+1 in" clock and "Reserve full" unverified on panel and strip — asserted in `booster_screen_test.rb`.
  - `[low]` `[patch]` (verification-gap) The tray's art palette assertion was dropped — the controller test asserts the tray's 109 × 112 palette values.
  - `[low]` `[patch]` (verification-gap) The per-layout `aria-labelledby` is unverified — asserted on the wide layout and on the phone.
  - `[low]` `[defer]` (verification-gap) Phone closing hint and no-season canister label unchecked — deferred as filed (narrow copy branches).
  - `[low]` `[patch]` (intent) `celebrationSteps` resets in `celebrate` and `layoutApplied` unasserted — assertions added to `booster.test.ts`.
  - `[false]` `[reject]` (intent) `assert_no_selector ".booster__info"` on the phone now checks visibility — Capybara's default has always been visible elements; the test asserts what the player sees, which AD-30's one tree keeps.
  - `[low]` `[reject]` (intent) The controllers have no unit tests — same as the blind row; the intent's acceptance names `booster_test.rb` and Vitest on `lib/booster.ts`.
  - `[low]` `[reject]` (intent) "Scripts run but the root never draws" is left to an untested CSS rule — the rule is two selectors; forcing the controller not to connect in a system test adds a harness for an unlikely state.
  - `[false]` `[reject]` (intent) Removing the counter assertions steps outside a strict reading of "unchanged" — the ticket's note drops the counter and its copy, so its assertions cannot stand.

### 2026-10-26 — Follow-up review pass
- verdicts: 6 findings — high 0, medium 1, low 4, maybe-false 1 (re-examined deferral); the first pass's patches read against `626e1fea`: the celebration's markup and controller match `BoosterCelebration.tsx` part by part (classes, order, `aria-*`, custom properties, the folded line's text, phone stepping and its still flag), `pack_card_fields` leaves `pack_opening_json` byte for byte (same keys in the same order, same label text under `booster.card_label`; key order asserted by `packs_controller_test.rb`), the reserve's next line and full flag follow the panel's and the strip's rules, and every whitespace-bearing server container is a flex box
- findings:
  - `[medium]` `[patch]` (verification-gap) The phone stepping test passed if "Next result" only rewrote "n / 2" and left the first banner in place; the folded banner on the phone, its hint in the panel and the still flag were unchecked — `booster_screen_test.rb` asserts the shown set's name changes and comes back, the still flag drops after a step, the folded banner on the phone carries its arrow and no stepper, and the panel's folded hint reads IN PROGRESS; checked by disabling the banner swap, which fails the test.
  - `[low]` `[patch]` (edge) The zoom reopened itself when a render (the countdown's tick, a bank answer) landed between the browser closing the dialog (Esc, Close, the scrim) and its `close` event, because the controller judged "opening" from `element.open`; the island opened it once per mount — opening is now judged from whether a card was shown, and `showModal` is skipped on an open dialog.
  - `[low]` `[patch]` (edge) A repost answered after its dialog closed wrote its status into the next opening, spoken over another card; the island dropped it with the unmounted dialog — the root passes the opening it reposted from and the zoom keeps the status only for that opening.
  - `[low]` `[patch]` (blind) The stage and the plate took "no hand" and "no plate" for a change on every render (`undefined !== null`), clearing both card lists and forgetting the gesture each second while the canister waits — keys compared after `?? null`; no visible effect before.
  - `[low]` `[patch]` (blind) Header comments the commit rewrote ran past the wrap (`celebration.ts`, `motion.ts`, `i18n.ts`) and kept planning ids (`i18n.ts`, `card_types.ts`, `packs_controller.rb`) — rewrapped, ids dropped on those lines only.
  - `[maybe-false]` `[defer]` (edge) The deferred throw holding the lock, read again: Stimulus 3.2's outlet getters connect an outlet's controller on demand, so `has…Outlet` true never meets a missing controller, and no DOM or data path in a sequence was found to throw; it stays deferred as filed.

### 2026-10-27 — Author decisions
- Accepted: the six counter assertions removed from `test/system/booster_test.rb` with the counter.
- Accepted: the open button's label assertions are weaker under the hidden label variants.
- No action: a throw inside a sequence keeping the navigation lock stays as is, no ticket.
- No action: "Reveal all" looking enabled during a Légendaire's hold stays as is, no ticket.

## Design Notes

**Root element** `section#booster.booster[data-controller=booster]` (keeps `aria-labelledby`, pointing at the shown layout's title; ids unique) with values: `openUrl`, `cardUrl`, `repostUrl` (empty without a season), `bankUrl`, `delimiter`, `packSize`, `season` (0 when none), `available`, `reserveFull`, `nextAvailableAt`, `serverTime`, `nextPackSize` (0 when none), `strings` (Object, `booster.strings` camelized, plural hashes kept). Targets: `rarity` `<template>` per tier (`data-tier`, `data-name`, the tier's `booster-card__label-icon` pixel icon), live region with an announcement `<template>`, and for an opened pack: `pack` data (token, kind, card back, url), one `card` target per card (slug, season, tier, cover URL, title, year, label) with three `face` `<template>`s (`data-index`, `data-size` s/m/xl, rendered by `CardComponent(booster: true)`), one `setTier` target per row (kind, key, name, tier, required, held, total, url, `data-thresholds` as space-separated `tier:required`). The root rebuilds an `OpeningAnswer`-shaped value from them for `start()`; faces live in a root map index → size → `<template>`, filled by `serverTemplate()` from each new answer.

**Regions (children):** `booster-info` on both `aside.booster__info` and `.booster-strip` (pips, reserve count, cards per pack, next clock and spoken time, reserve full, state tone; state words rendered per status, shown from the root's `data-status`); `booster-actions` (Open with its three label variants, Reveal all, Back guarded while locked, reason line; moved by the root between the panel's host and `.booster__phone-actions` on each applied layout, each arrangement as today); `booster-canister` (zone: canister parts for animation, reset on dock, hint, phone facts, empty reserve with next time); `booster-stage` (shake/dim/fx/flash surfaces, result head, `ol.booster__deal` and `ol.booster__pile`, desktop hint, banner from its template; builds card slots from its card `<template>` with the face the root hands it, delegates click and pointer gestures per slot `data-position`, exposes card parts and slots for the root's animations, pile poses and `inert`); `booster-plate` (hint, plate with pop, Store); `booster-tray` (slots from templates, filled slot button with canvas cover and icon, zoom intent); `booster-zoom` (`<dialog>` filled per zoomed card: xl face clone, title, line, icon, href, ◀ ▶ enabled, repost, close, swipe step); `booster-celebration` in the panel and in the plate band (builds results, folded banner, ticks, marks, sparks from its templates and icons; phone stepping). Names are indicative; the split per region is not.

**Flow.** Child event → dispatch → root handler → transition → render (each outlet driven with a plain view and composed text) → focus → events from state before/after (as `reflect` does). Layout applied → root rebuilds the hand in the layout's list at `faceSize(layout)`, moves actions, redraws celebration and tray. A gesture's start asks the root through a cancelable dispatch (the root prevents default when `canStore`), like the trade board's `move`.

**Timers and teardown.** A `lib/booster_timers.ts` port of `useIslandTimers` (`wait` leaves the promise pending once disposed, `later`, `dispose`); root `disconnect()` disposes, releases the lock (`navigation-locked: false` when held), dispatches `opening-revealing: false`, aborts matchMedia/visibility listeners.

## Verification

**Environment:** work only in `/home/teyermann/projets/gameble/.claude/worktrees/epic-port-off-react` and run every command from it; export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react CHROME_BIN=/usr/bin/chromium` for every Rails command; the machine is short on memory: run system test files one at a time, never two test commands at once; `git checkout db/schema.rb` if a run rewrites it; no new npm dependency; do not commit, push or run `script/github_board/sync.py`.

**Commands:**
- `bin/rails test test/system/booster_test.rb` -- all pass, three runs in a row.
- `bin/rails test test/system/<file>.rb` for `shell`, `card_preview`, `countdown`, `hub`, `settings`, `daily_bonus`, `live_updates`, one at a time -- all pass.
- `bin/rails test` -- all pass.
- `npm run test:js`, `npm run typecheck` -- pass.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `script/check_markup_apis` -- clean.

## Auto Run Result

**Summary:** the booster leaves React. The server renders the whole screen as one tree holding the three layouts (panel and strip, actions moved between the panel and the phone's host, canister, stage with the deal row and the pile, plate band, tray, zoom dialog, two celebration hosts), with fixed copy in every variant shown by CSS from the root's `data-*`, run-time templates under `booster.strings`, and `<template>`s for everything that appears later (card slot, each opened card's face at s/m/xl, tray slots, plate, banner, celebration parts, live-region line, rarity icons). A `booster` root controller holds `lib/booster.ts`'s state, applies every transition, runs every sequence ported from `Booster.tsx` and drives eight child controllers through outlets; faces from the opening exchange go through `serverTemplate()`. Without JavaScript the tree stays hidden and the fallback form opens a capsule on its pack's page. `app/frontend/components/` and the Turbo Mount registration are gone; React and Turbo Mount stay installed for the next entry. The "n / 5" counter is not rebuilt (ticket note).

**Files changed:**
- `app/views/boosters/show.html.erb` and new partials (`_booster`, `_strip`, `_info`, `_next`, `_actions`, `_canister`, `_stage`, `_card`, `_plate`, `_tray`, `_zoom`, `_celebration`, `_opened`) — the server tree and the fallback.
- `app/helpers/boosters_helper.rb` — root values and outlets, `BOOSTER_ACTIONS`, strings, rarities, opened pack and set tier data, celebration templates; `booster_bank` unchanged. `app/helpers/packs_helper.rb` — `pack_card_fields` shared, label key moved. `app/controllers/boosters_controller.rb` — opened pack and cards to the view.
- `app/frontend/controllers/booster_controller.ts` and `booster_{info,actions,canister,stage,plate,tray,zoom,celebration}_controller.ts` — root and children.
- `app/frontend/lib/booster.ts` (+test) — types moved in, `revealedCount` dropped, celebration step; `lib/booster_{timers,swipe,countdown,markup,templates}.ts` (+tests) new; `booster_motion`, `booster_keyframes`, `booster_effects`, `booster_bank`, `booster_page` touched (moves, de-islanded wording); `booster_props.ts` deleted.
- `app/frontend/components/` deleted (the island, its nine sub-components, the error boundary and four hooks); `app/frontend/entrypoints/application.ts` without Turbo Mount or React.
- `app/frontend/styles/booster.css`, `booster-layouts.css` — one tree drawn per `data-layout`, variants, fallback rule; counter rules gone.
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` — `boosters.island` becomes `booster.*` and `booster.strings.*`.
- Comment wording in shell views, chrome controllers, lib headers, `packs_controller.rb`, `config/routes.rb`.
- `test/controllers/boosters_controller_test.rb` rewritten against the markup; `test/system/booster_test.rb` — the allowed changes only; `test/system/booster_screen_test.rb` added.

**Review:** 31 findings (medium 5, low 18, false 6, maybe-false 2). Patched: the vacuous set tier check, faces after `?pack=`, multi-result and folded celebrations with phone stepping, the reserve's next line and full flag (medium, tests added); stale island wording, dead exports, shared card fields, celebration parts by class, CSS comment alignment, palette and outlet assertions, `aria-labelledby` per layout, `celebrationSteps` resets (low). Deferred: a throw inside a sequence holding the lock (medium, unverified); the phone closing hint and the no-season canister label untested (low). Rejected: see the triage log (status list duplication inherent to AD-18 variants; per-second render idempotent as the island's; broad `[hidden]` rule harmless; repost toast after leaving matches the island; reconnect and no-`showModal` paths unreachable; the back-office grep match is a pre-existing negative assertion; counter removal per the ticket's note).

**Follow-up review recommended: true** (patched by verdict: high 0, medium 4 entries, low 8). Unverified risk: the patches changed the celebration's markup (new classes, `before()`/`after()` text placement) and the shared `pack_card_fields`, which no lens has read, and the 1,300-line root controller is checked only through the system tests.

**Verification:**
- `bin/rails test test/system/booster_test.rb`: 43 runs, 0 failures, three runs in a row after the patches (three more by the implementer before them); its diff from `626e1fea` holds only the counter removals, the two renamed keys and the replaced failure test.
- One at a time, green after the patches: `booster_screen` (6), `shell` (23), `card_preview` (5), `countdown` (4), `hub` (16), `settings` (13), `daily_bonus` (6), `live_updates` (10).
- `bin/rails test`: 3201 runs, 0 failures. `npm run test:js`: 64 files, 708 tests. `npm run typecheck`, `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bundle exec rubocop` (950 files), `i18n-tasks missing`/`unused`, `script/check_markup_apis` clean. `db/schema.rb` untouched.

**Residual risks:** no visual check beyond the system tests (phone width, motion on, the celebration's look after the class changes); the open-button label assertions are weaker under hidden variants; a sequence that throws would keep the navigation lock (deferred).
