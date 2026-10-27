---
title: 'The trade board in Stimulus'
type: 'refactor'
ticket: '1'
created: '2026-10-26'
status: 'built'
baseline_revision: 'f2096c5b0daef0ab646a36b07ab05dc752052743'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: ['blind-hunter', 'edge-case-hunter', 'verification-gap', 'intent-alignment']
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The picker's paging past 36 cards, its phone fold button, its comparison chips and the root's `fold`/`more` action routes are not exercised in a browser.
    evidence: |-
      trades_test.rb uses at most 5 cards per picker and never checks a comparison chip or the fold button; the pure transitions (showMore, toggleFold, setFilter with chips) are covered in trade_board.test.ts, but a typo in TradesHelper::BOARD_ACTIONS (`fold: :toggleFold`, `more: :showMore`) or a broken IntersectionObserver re-observe would ship green. The React island was equally untested there. Worth one system test (a chip, the fold at phone width, a 37th card scrolled into view) before the booster port copies the pattern.
    location: >-
      app/frontend/controllers/trade_board_picker_controller.ts, app/helpers/trades_helper.rb BOARD_ACTIONS
    severity: low
---

<intent-contract>

## Intent

**Problem:** The trade board's editing view and picker are a React island (`TradeBoard`, `TradePicker`, `QuantityStepper`) glued to three Stimulus controllers by the `gameble:trade-changed` and `trade-editing` window events, with copy and card data shipped as one JSON props value. That contradicts AD-16, AD-18 and AD-30, and the booster's port needs the conventions this port sets.

**Approach:** Render every part of the board on the server (read sides, edit sides, picker items, line and stepper `<template>`s, copy variants) and drive it with a `trade-board` root controller that holds one state value from `app/frontend/lib/trade_board.ts`, plus `trade-board-side`, `trade-board-picker` and `trade-board-send` children that dispatch intents and are driven through the root's outlets. Server HTML from the faces JSON batch is placed into `<template>`s by one shared helper; a CI step refuses markup-building APIs anywhere else in `app/frontend`.

## Boundaries & Constraints

**Always:**
- `test/system/trades_test.rb` passes byte-for-byte unchanged (selectors, wording, focus, keyboard, swap frames). Other controller tests stay unchanged except the island-props test, rewritten against the markup.
- Root (`trade-board`, exported named class) alone holds the module state, applies every transition, runs every sequence (picker open/close, undo, swap), writes `data-editing`/`data-swapping`/live-refresh hold on its own element, composes run-time strings with `t()` from its `strings` Object value (templates only, from `trade_board.strings`), and hands children plain view objects and composed text. Children write only inside their own region, report intents with `this.dispatch(..., { cancelable: true })` caught by `data-action` on the root, never reference each other.
- Outlets declared on the root with selectors scoped to `#trade-board`; optional peers checked with `has…Outlet`; state built in `initialize()`/`connect()` so outlet callbacks before connect are harmless; no outlet reference kept past disconnect.
- Initial state from markup: scalar Stimulus values, and `data-*` on root targets (one `card` target per picker item with side, key, title, rarity, owned, reserved, max, copies, other-copies; one `line` target per received line; one `face` `<template>` per line card).
- Fixed copy rendered server-side in every variant and shown by CSS from `data-editing` (root) or `data-side` (picker); only counts/values composed in the browser.
- Browser storage read/written only by `lib/trade_board_draft.ts`.
- No `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`DOMParser`/`createContextualFragment` in `app/frontend` outside `lib/server_html.ts` and its test. Script creates only decorative `aria-hidden` swap effects; everything else is cloned from server `<template>`s or moved.
- Server HTML carries no `style` attribute; no database ids in markup (no `value="<id>"`, no `trade_id`).
- Every string in `en.yml` and `fr.yml`; French plurals with `zero`.

**Never:**
- No feature or visible change; no new endpoint; the faces JSON endpoint and its contract stay as they are.
- No React import in trade code; `turbo-mount` and React stay installed for the booster (story 4 removes them).
- No `gameble:*` event for the screen's own traffic; `gameble:trade-changed` and `gameble:trade-editing` and their detail types leave `lib/events.ts`.
- Do not move the draft to the server or the picker filters to a Turbo Frame.
- Do not touch the booster's code or `boosters.*` copy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Counter in place | read board (`yours`), click Counter | `data-editing` set, URL replaced by counter path, focus on own add slot, refresh held | modified clicks open normally |
| Discard unchanged / changed | editing, Discard | unchanged: back to read view, URL to board, focus Counter; changed: undo dialog, confirm restores received lines and forgets the draft | — |
| Draft kept | lines differ from received | draft saved under its key; equal again → forgotten; reopened board starts from the draft clamped to maxima | storage refused → board works unsaved |
| Picker limits | 4 cards placed, pick a 5th | refused line shown, selection unchanged | unavailable card (max 0) not pickable, `aria-disabled` |
| Picker filters | query/rarity/chips | items shown in server order, paged by 36, results count, "no match" line, Clear focuses search, per-side filters kept between openings | — |
| Faces | keys shown or placed without face | batch-loaded (36/request, 2 at once, retries), placed by the helper, cloned into pending slots | failed batch leaves slot pending |
| Send blocked | friend side empty | submit disabled, reason shown and referenced by `aria-describedby` | server still refuses |
| Live refresh | morph while not editing | root rebuilds its state from the new markup and re-renders | held while editing, picker open or swap playing |
| Swap | accepted trade (`swap` value) | cards fly across with squash, burst, focus on message; reduced motion: two crossfades | skipped on Turbo preview |
| No JavaScript | counter page | received lines rendered with their hidden fields; sending submits current terms | — |

</intent-contract>

## Code Map

- `app/frontend/components/TradeBoard.tsx`, `TradePicker.tsx`, `QuantityStepper.tsx` -- behaviour to reproduce exactly (focus rules, picker paging/IntersectionObserver, grid arrows via `gridMove`/`columnsOf`, stepper keys via `stepperKey` and mousedown keep-focus, before-cache close, labels), then delete.
- `app/frontend/entrypoints/application.ts:13,36-38` -- drop the `TradeBoard` import and registration; Booster registration stays.
- `app/frontend/controllers/trade_board_controller.ts` -- current edit/undo/restore/abandon/replaceUrl (history trail) logic; becomes the root. `trade_send_controller.ts`, `trade_swap_controller.ts` -- folded in, then deleted.
- `app/frontend/lib/trade_board.ts` -- pure helpers kept (`initialLines`, `toggle`, `setQuantity`, `remove`, `sideCount`, `showsOpenHelp`, `stepperKey`, `gridMove`, `columnsOf`, filters); `sendable` changes signature; imports from `events.ts` removed.
- `app/frontend/lib/trade_draft.ts`, `trade_faces.ts`, `trade_swap.ts` (+ tests) -- renamed `trade_board_draft.ts`, `trade_board_faces.ts`, `trade_board_swap.ts` (`git mv`).
- `app/frontend/lib/events.ts` -- drop trade events. `lib/i18n.ts` `t()`, `lib/dialog.ts` `openDialog`, `lib/live_refresh_hold.ts`, `lib/history_trail.ts`, `lib/motion.ts` -- reuse.
- `app/frontend/controllers/live_refresh_controller.ts` -- morph refresh (`Turbo.session.refresh(..., {method: "morph"})`), held by `data-live-refresh-hold`, open dialogs, unsent inputs; read-only here.
- `app/frontend/controllers/toast_controller.ts:90`, `moving_cards_controller.ts:83` -- existing template-cloning style.
- `app/helpers/trades_helper.rb:132-238` -- `trade_board_locals`, `trade_board_props`, `trade_draft_props`, `trade_island_*`: replace with helpers feeding the partials (per-side pick rows sorted as today, lines, maxima, labels); keep `trade_card_key`, `trade_card_faces`, `trade_draft_key`, `trade_counter_key`, `trade_card_limit`.
- `app/views/trades/_board.html.erb`, `_draft_board.html.erb`, `_board_middle.html.erb`, `_side.html.erb`, `_undo_dialog.html.erb`, `new/show/edit/index.html.erb` -- board markup; `_side` keeps only the read branch.
- `app/controllers/trades_controller.rb` -- unchanged except what the helper rename needs (it should need nothing).
- `app/frontend/styles/trades.css` -- `.trade-island*` (471-473, 547), `.trade-board--swapping` (1039), `.trade-board__action-set[hidden]` (291), picker title short/long rules, `.stepper*`; `[hidden]` is not global, add rules where a displayed element is toggled.
- `config/locales/{en,fr}.yml` `trades.island.*` (en 2239, fr 1497), `trades.side.{cards,cards_copies,quantity_label,max}`; `config/i18n-tasks.yml:35-36`.
- `test/controllers/trades_controller_test.rb:408-460` -- island props test to rewrite; lines 84-130 assert the read board and must keep passing (`.trade-board__message` exact text, `.trade-side--friend .card` count 1, `.trade-side--own .trade-card__reserved` count 0, no `value="<trade id>"`).
- `test/system/trades_test.rb` -- the acceptance net; read-only.
- `config/ci.rb`, `.github/workflows/ci.yml` (job with `npm ci`, after "Run JavaScript tests") -- add the markup-API step. `vitest.config.ts` -- node environment stays.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md` Stack table -- add the happy-dom row.

## Tasks & Acceptance

**Execution:**
- [x] `app/frontend/lib/server_html.ts` + `server_html.test.ts` -- `serverTemplate(html, doc = document): HTMLTemplateElement` placing the HTML unchanged as the template's content; test file starts with `// @vitest-environment happy-dom`; add `happy-dom` (exact pin, 21.0.x) to devDependencies via `npm install -D -E`.
- [x] `script/check_markup_apis` (+ step in `config/ci.rb` and `.github/workflows/ci.yml`) -- fails listing offending lines when the five APIs appear in `app/frontend` outside the helper and its test.
- [x] `app/frontend/lib/trade_board.ts` + `trade_board.test.ts` -- add the screen state (catalogue per side, received and current lines, editing, picking side, picker selection/refused/active key/shown count, per-side filters and fold) and pure transitions: start (draft or received), edit, restore, removeLine, setLineQuantity, openPicker, togglePick, setPickQuantity, setFilter, toggleFold, clearFilters, showMore, moveActive, place, closePicker; derived: changed, sendable, draft sides, picker view (visible/shown keys, empty reason, counts). Vitest covers each transition and derived value.
- [x] `app/frontend/lib/trade_board_draft.ts`, `trade_board_faces.ts`, `trade_board_swap.ts` (+ tests) -- renamed; draft API unchanged.
- [x] `app/frontend/lib/stepper.ts` -- shared stepper reflection (aria-valuenow/max/valuetext/label, value and max texts, disabled buttons) used by side and picker.
- [x] `app/frontend/controllers/trade_board_controller.ts` -- root (see Design Notes); `trade_board_side_controller.ts`, `trade_board_picker_controller.ts`, `trade_board_send_controller.ts` -- children; delete `trade_send_controller.ts`, `trade_swap_controller.ts`, the three components; `application.ts`, `events.ts` updated.
- [x] `app/helpers/trades_helper.rb`, `app/views/trades/_board.html.erb`, `_draft_board.html.erb`, `_board_middle.html.erb`, `_side.html.erb`, new `_edit_side.html.erb`, `_line.html.erb`, `_stepper.html.erb`, `_picker.html.erb`, `_pick.html.erb`, `show/edit/new/index.html.erb` -- server markup per Design Notes.
- [x] `config/locales/en.yml`, `fr.yml`, `config/i18n-tasks.yml` -- `trades.island.*` and the four `trades.side` templates move to `trade_board.*` (fixed words) and `trade_board.strings.*` (run-time templates); the read side's count reads the same keys.
- [x] `app/frontend/styles/trades.css` -- visibility by `[data-editing]`, `[data-swapping]`, picker `[data-side]`, stash hidden; drop island rules.
- [x] `test/controllers/trades_controller_test.rb` -- rewrite the island test against markup: card targets per side with their data, received line targets, face templates of the lines' cards only, strings value scope, counter form fields, no ids.
- [ ] Architecture Stack table -- `happy-dom` row with the installed version.

**Acceptance Criteria:**
- Given the branch, when `bin/rails test test/system/trades_test.rb` runs (CHROME_BIN=/usr/bin/chromium), then every test passes and `git diff <baseline> -- test/system/trades_test.rb` is empty.
- Given the repo, when `rtk proxy grep -rn "components/Trade\|QuantityStepper\|trade-changed\|trade-editing\|turbo_mount(\"TradeBoard" app config` runs, then nothing matches.
- Given a planted `el.innerHTML = x` in any `app/frontend` file, when `script/check_markup_apis` runs, then it exits non-zero naming the file; without it, it exits zero.
- Given `npm run test:js`, then the trade board module's transitions and `server_html` (under happy-dom) are covered and pass, the other tests staying in node.

## Implementation Notes

- Built by a coding subagent from this plan; every Execution task landed. Root `trade-board` (named export `TradeBoardController`) holds the state from `lib/trade_board.ts`; children `trade-board-side`, `trade-board-picker`, `trade-board-send` dispatch cancelable intents routed by `TradesHelper::BOARD_ACTIONS` on the root's `data-action`; outlets scoped to `#trade-board`.
- Picker items are all server-rendered (`_pick`) into a hidden stash `<ul>` and moved into the grid in shown order, so `.trade-pick:last-child` is the last shown card.
- The root keeps writing the `trade-board--editing` and `trade-board--swapping` classes beside `data-editing`/`data-swapping`: unchanged controller tests and `test/system/live_updates_test.rb:234` read them.
- happy-dom is pinned at 20.14.5, not 21.0.x as the task said: the coordinator asked for a release several weeks old (21.0.x was under two weeks old).
- Deviation: the edit sides no longer render the `.trade-side__none` "nothing to place" paragraph (only the old no-JS fallback showed it; the picker gives the reason). Two controller tests that asserted it were changed: one rewritten to check the edit sides drop the unplaceable lines and the picker data that carries the reason, one deleted.
- Deviation: the no-JS counter page now carries hidden quantity fields and a JS stepper instead of editable number fields; without JavaScript the counter sends the current terms.
- Added `test/system/trade_board_test.rb` (faces placed in picker and lines; state rebuilt after a live-refresh morph), outside the Code Map.
- First full run hit 81 Vite "can't find images/pixel" errors from stale test assets; `RAILS_ENV=test bin/vite build --clear --mode=test` fixed them.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 34 findings — high 3, medium 4, low 19, false 8, maybe-false 0
- findings:
  - `[low]` `[reject]` (intent) No-JS counter page lost its editable number fields (hidden fields + JS stepper now) — real but only without JavaScript on a `allow_browser :modern` app; the island already needed JS to add cards; restoring number inputs beside the stepper adds a second editing path.
  - `[false]` `[reject]` (intent) "Markup-building APIs" read narrowly (five sinks) — the epic's Done-when 4 names exactly these five APIs; the check fails on each.
  - `[false]` `[reject]` (intent) Vitest does not cover the root's sequences — the intent asks Vitest to cover the module's transitions, which `trade_board.test.ts` does; the controller sequences are covered by `trades_test.rb`, `live_updates_test.rb` and the new board system test.
  - `[low]` `[patch]` (intent) `server_html.test.ts` "runs no script" case says little — test deleted.
  - `[low]` `[reject]` (intent) happy-dom pinned 20.14.5 while the plan says 21.0.x — the coordinator asked for a release several weeks old; the fix would edit this plan; recorded in Implementation Notes.
  - `[false]` `[reject]` (intent) New system test outside the Code Map — adds coverage, harms nothing.
  - `[low]` `[patch]` (blind) `package-lock.json` root name became "epic-port-off-react" — restored to "gameble".
  - `[false]` `[reject]` (blind) `editingValue` never written back, so a cache restore could reopen in the wrong mode — trade pages are exempt from the Turbo cache (`_screen.html.erb` `turbo_exempts_page_from_cache`) and a morph cannot run while editing (hold), so the value always matches the URL's server markup when read.
  - `[low]` `[reject]` (blind) Markup check misses `dangerouslySetInnerHTML`, `setHTMLUnsafe`, `document.write`; script itself untested — the five APIs are the epic's definition; the only `dangerouslySetInnerHTML` left is the booster island, removed by entry 3; planted-innerHTML check run by hand (exit 1).
  - `[low]` `[patch]` (blind) Explanatory prose comments in the new files break AGENTS.md's comment rule — deleted, keeping only external-constraint one-liners.
  - `[low]` `[patch]` (blind) `server_html.test.ts` script test proves nothing and leaks a template into `document.body` — same root cause as the intent row; test deleted.
  - `[low]` `[reject]` (blind) `lib/stepper.ts` imports `stepperKey` from the screen module; paging constants from the faces module — no caller diverges today (the stepper serves only the trade board); a move is churn without a named harm.
  - `[false]` `[reject]` (blind) Stepper DOM half untested; a button without `data-step` dispatches NaN — every stepper button is server-rendered with `data-step` (`_stepper.html.erb`); `reflectStepper`, keys and buttons are exercised by `trades_test.rb` (arrow keys, more button, aria-valuenow asserts).
  - `[low]` `[defer]` (blind) `BOARD_ACTIONS` route names are not checked against the root's methods — every route but `fold` and `more` is driven by `trades_test.rb`; grouped with the paging/fold/chips gap below.
  - `[low]` `[reject]` (blind) Plan shows unchecked tasks and empty notes — bookkeeping of this plan, filled at Finalize; not a code defect.
  - `[high]` `[patch]` (blind) Face loader keeps fetching after disconnect and re-requests failed keys on every render — the re-request half is the fetch loop below (patched); fetches after disconnect are bounded (three attempts) and land on a board whose `render` returns early, rejected.
  - `[low]` `[reject]` (blind) "4 cards at most" hard-coded in copy — pre-existing wording carried over from `trades.island.*`; the limit is a game rule.
  - `[low]` `[reject]` (blind) Server and browser compute initial lines separately; faces shipped for dropped lines — both apply the same rules (clamp, dedupe, drop unavailable, cap 4); an unused face template costs a few bytes.
  - `[false]` `[reject]` (blind) `cardFrom` trusts `data-rarity` — the attribute is server-rendered from `Catalog::Rarity` tiers only.
  - `[medium]` `[patch]` (verification-gap) `live_updates_test.rb:234` probes `.trade-board--swapping`, which nothing set any more — the root now toggles that class with `data-swapping`, so the probe sees the swap again.
  - `[medium]` `[patch]` (verification-gap) Nothing checks the state rebuild after a morph — system test added: a board morphed to YOUR TURN is countered and shows its received lines.
  - `[low]` `[patch]` (verification-gap) Nothing checks an arrived face is not fetched again — loader tests added (recorded arrival, and a key answered without a face, not requested again).
  - `[low]` `[patch]` (verification-gap) `server_html` script test cannot fail — test deleted.
  - `[low]` `[defer]` (verification-gap) Picker paging (>36 cards), fold button and comparison chips are not exercised in a browser — pure transitions are tested; the island was equally untested here; deferred.
  - `[high]` `[patch]` (verification-gap) Fetch loop for a face the endpoint never returns — `faceLoader` settled a key answered without a face, and each arrival's render asked for it again; it now remembers such keys and never asks again.
  - `[low]` `[patch]` (verification-gap) `package-lock.json` name — same as the blind row; restored.
  - `[low]` `[reject]` (verification-gap) Markup check misses `dangerouslySetInnerHTML` — same reasoning as the blind row.
  - `[low]` `[reject]` (verification-gap) happy-dom version differs from the plan — same as the intent row.
  - `[high]` `[patch]` (edge-case) Endless face fetch loop when the endpoint omits a key — same root cause; patched in `faceLoader` with a test.
  - `[false]` `[reject]` (edge-case) Picker order wrong after a Turbo cache restore — trade pages are never cached by Turbo, and a morph rewrites the stash in server order before the state is re-read.
  - `[medium]` `[patch]` (edge-case) Edit side's "no card available" paragraph stays after placing other cards — the paragraph (never shown by the island) and `trade_nothing_to_place` removed; the picker states the reason.
  - `[medium]` `[patch]` (edge-case) `live_updates_test.rb:234` swap probe — same root cause as the verification-gap row; class restored.
  - `[false]` `[reject]` (edge-case) Removed `editingValue` write-back — same refutation as the blind row.
  - `[low]` `[reject]` (edge-case) happy-dom 20.14.5 vs the plan's 21.0.x — same as the intent row.

### 2026-10-26 — Follow-up review pass
- verdicts: 2 findings — high 0, medium 2, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The face loader is built once in `initialize()` with `facesBatchValue`; a WAITING board renders no batch value (0), so after a live-refresh morph turns it to YOUR TURN the picker asked one key per request — the root now builds a new loader in its `turbo:morph` handler; `test/system/trade_board_test.rb` ("a board a live refresh turns…") records the faces requests and asserts the picker's two missing faces arrive in one batch (it fails with the old loader kept).
  - `[medium]` `[patch]` The earlier patch made a batch that failed every attempt never asked for again and flipped the baseline test — `faceLoader` frees the keys of an exhausted batch so a later request asks again; keys answered without a face stay never-asked-again; the baseline test "…then lets a later request ask for it" is restored and the no-loop test kept.

### 2026-10-27 — Author decisions
- Accepted: without JavaScript the counter page sends the current terms and cannot change quantities.
- Accepted: the edit sides drop the "nothing to place" paragraph; its two controller tests rewritten and deleted as recorded.

## Design Notes

**Markup.** `#trade-board` root (PanelComponent section) with values `editing` (Boolean), `focus` ("heading" on show and draft, "side" on the counter page, "" on index), `forget`, `draftKey` (draft or counter key), `counterUrl`, `boardUrl`, `facesUrl`, `facesBatch`, `swap`, `strings` (Object). Server renders `data-editing` on the root when editing, so CSS works before JS. For a `yours` trade and the draft, each side renders twice: the read `_side` (class `trade-board__read-only`, absent for drafts) and `_edit_side` (`trade-side--editing trade-board__edit-only`, `data-controller="trade-board-side"`, `data-side`), whose list holds server lines only when the page starts editing (counter page; empty on show, so read-board assertions keep one `.card` per side), its line `<template>` (face slot pending, stepper, remove button, hidden `give|take[key]` field with `form=`), count, add slot and help. One picker `<dialog id=...>` (`data-controller="trade-board-picker"`, `aria-labelledby="trade-picker-title"`) holds per-side variants (titles long/short, note, compare chips, none messages) shown by its `data-side`, the shared search/rarities/fold/results/clear/empty/refusal/count/Place/Cancel, a grid `<ul>` and a hidden stash `<ul>` holding every server-rendered `_pick` item (the root's `card` targets, fixed label/owned/reserved/available text, empty face slot), and a stepper `<template>`. Messages: two `.trade-board__message` paragraphs (read-only, edit-only).

**Flow.** Child event → dispatch → root handler → `state = transition(state, …)` → `render()` drives each outlet with a view (lines with composed labels, counts, add/help visibility; picker shown keys, pressed/active/disabled per key, texts, filter values) → focus step if any → persist draft (save if changed, else forget) and `sendOutlet.reflect(blocked)`. Faces: root keeps `Map<key, HTMLTemplateElement>` seeded from `face` targets, extended by `serverTemplate()` on each batch, and gives children `faceFor(key)` (a clone of the content) to fill pending slots. Picker reconciles the grid by moving items between stash and grid in shown order, so `:last-child` is the last shown card.

**Example** -- a child reports, the root decides:
```ts
// picker
keydown(event: KeyboardEvent) {
  const sent = this.dispatch("move", { detail: { key: event.key, columns: this.columns() }, cancelable: true })
  if (sent.defaultPrevented) event.preventDefault()
}
// root
move({ detail, preventDefault }) { const next = moveActive(this.state, detail.key, detail.columns); if (next === this.state) return; preventDefault(); … }
```

**No JavaScript.** Counter page renders received lines with hidden fields; adding or changing quantities needs JS, as with the island.

## Verification

**Environment:** work only in the git worktree holding this plan (`/home/teyermann/projets/gameble/.claude/worktrees/epic-port-off-react`) and run every command from it; export `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react` and `CHROME_BIN=/usr/bin/chromium` for every Rails command; do not commit, push or run `script/github_board/sync.py`; if a test run rewrites `db/schema.rb`, restore it with `git checkout db/schema.rb`.

**Commands:**
- `bin/rails test test/system/trades_test.rb` (with `CHROME_BIN=/usr/bin/chromium`, `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_react`) -- all pass.
- `bin/rails test` -- all pass.
- `npm run test:js` and `npm run typecheck` -- pass.
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `bin/rubocop`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- clean.
- `script/check_markup_apis` -- passes; fails with a planted `innerHTML`.

## Auto Run Result

**Summary:** the trade board leaves React. A `trade-board` root controller over the DOM-free state module `lib/trade_board.ts` drives `trade-board-side`, `trade-board-picker` and `trade-board-send` children through outlets. Every part of the board is rendered by the server (read and edit sides, picker items, line and stepper `<template>`s, copy variants shown by CSS from `data-editing` and the picker's `data-side`). Run-time copy is composed by `t()` from `trade_board.strings`. Faces from the JSON batch go through the one helper `lib/server_html.ts`, and `script/check_markup_apis` (in `config/ci.rb` and `ci.yml`) refuses markup-from-string APIs elsewhere. `TradeBoard`, `TradePicker`, `QuantityStepper`, `trade_send`/`trade_swap` controllers and the `trade-changed`/`trade-editing` events are gone.

**Files changed:**
- `app/frontend/lib/trade_board.ts` (+test) — board state and transitions; `trade_board_draft.ts`, `trade_board_faces.ts`, `trade_board_swap.ts` (+tests) renamed from `trade_*`, the loader never re-asks a key.
- `app/frontend/lib/server_html.ts` (+happy-dom test), `app/frontend/lib/stepper.ts` (+test) — the HTML-in-JSON helper and the shared stepper reflection.
- `app/frontend/controllers/trade_board_controller.ts`, `trade_board_side_controller.ts`, `trade_board_picker_controller.ts`, `trade_board_send_controller.ts` — root and children; `trade_send_controller.ts`, `trade_swap_controller.ts`, `components/TradeBoard.tsx`, `TradePicker.tsx`, `QuantityStepper.tsx` deleted; `entrypoints/application.ts`, `lib/events.ts` trimmed.
- `app/helpers/trades_helper.rb`, `app/views/trades/*` (`_board`, `_draft_board`, `_board_middle`, `_side`, new `_edit_side`, `_line`, `_stepper`, `_picker`, `_pick`, `_faces`) — server markup and the data it carries.
- `app/frontend/styles/trades.css` — visibility from `data-*`, island rules dropped.
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` — `trades.island.*` becomes `trade_board.*` and `trade_board.strings.*`.
- `script/check_markup_apis`, `config/ci.rb`, `.github/workflows/ci.yml` — the markup-API CI step.
- `package.json`, `package-lock.json` — happy-dom 20.14.5; architecture Stack row.
- `test/controllers/trades_controller_test.rb` — island-props test rewritten against the markup, swap/counter assertions renamed, two "nothing to place" tests changed; `test/system/trade_board_test.rb` added.

**Review:** 34 findings (high 3, medium 4, low 19, false 8). Patched: the endless face-fetch loop (high, three lenses), the dead swap probe in `live_updates_test.rb` (class restored), the missing morph-rebuild test, the stale "nothing to place" paragraph, the lockfile name, the trivial helper test, the loader dedupe tests, the prose comments. Deferred: picker paging/fold/chips untested in a browser. Rejected: see the triage log (cache-restore claims refuted by the trade pages' cache exemption; markup-check scope is the epic's five APIs; no-JS editable quantities; hard-coded "4" pre-existing; happy-dom pin per coordinator).

**Follow-up review recommended: true** (patched by verdict: high 1, medium 3, low 4). Unverified risk: the morph-rebuild path is covered by one system test only. (Follow-up pass: a failed batch is asked again by a later request; the loader is rebuilt after a morph so the batch size follows the new markup.)

**Verification:**
- `bin/rails test`: 3201 runs, 0 failures, 0 errors (after the patches).
- `npm run test:js`: 57 files, 606 tests passed; `npm run typecheck` clean; `bin/rails zeitwerk:check` all good; `bundle exec packwerk check` no offenses; `bin/rubocop` no offenses; `i18n-tasks missing` and `unused` clean.
- `script/check_markup_apis`: exit 0; exit 1 naming the file with a planted `innerHTML`.
- `test/system/trades_test.rb`: unchanged (`git diff` empty); 15 consecutive runs green before the review patches; after the patches 25 runs (trades, trade_board, live_updates) green, run by the implementer. A wider post-patch system batch (friends, settings, shell, hub, share_card plus a 10-run repeat) was killed by the host for low memory and not rerun.
- The implementer saw one unexplained `trades_test.rb` failure in about 20 runs before the review; 15 later runs did not reproduce it.

**Residual risks:** the unreproduced intermittent failure above; no visual check at phone width or with reduced motion beyond the system tests; the no-JS counter page can no longer change quantities.

