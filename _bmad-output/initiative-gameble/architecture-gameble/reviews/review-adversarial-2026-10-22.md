# Adversarial review: the 2026-10-22 update (Hotwire only)

Spine reviewed: `architecture-gameble.md` (updated 2026-10-22). The change is AD-16, now "Server-rendered pages, Hotwire only", with the port freeze in its last bullet. I read it together with AD-18 (copy reaches a controller as a Stimulus value), AD-23 (the opening exchange) and AD-27 (layout, breakpoints, motion), which it touches.

Units one level down: the trade board port, the booster port (the next two units AD-16 orders), and the first bug fix that touches either screen while its port is open.

Code read: `app/frontend/components/Booster.tsx`, `BoosterView.tsx`, `TradeBoard.tsx`, `TradePicker.tsx`; `app/frontend/lib/booster.ts`, `booster_page.ts`, `booster_effects.ts`, `opening.ts`, `trade_board.ts`, `trade_draft.ts`, `trade_faces.ts`, `events.ts`, `i18n.ts`; `app/frontend/controllers/trade_board_controller.ts`, `trade_swap_controller.ts`, `toast_controller.ts`; `app/views/trades/_board.html.erb`, `app/views/boosters/show.html.erb`; `app/helpers/boosters_helper.rb`, `trades_helper.rb`; `app/frontend/styles/booster-layouts.css`, `trades.css`; `test/system/booster_test.rb` (39 tests), `test/system/trades_test.rb` (12 tests).

Method: for each rule, I built two units that each follow every AD word for word and still don't fit together. Each finding names the clash, points at the code that makes it likely, and gives the rule text that closes it.

**Verdict: the direction is sound, but AD-16 is not yet a build contract for a rich screen.** It says what must not happen (no view library, no HTML from script, no game state in the browser) and names the parts (one module, several controllers, outlets, `data-*`). But it doesn't say how those parts connect. The codebase has no precedent to copy: no controller in `app/frontend/controllers` uses outlets today, and the two existing intra-screen events (`trade-changed`, `trade-editing`) bridge React to Stimulus. So the trade board port will invent the anatomy, and nothing tells the booster port to inherit it.

On top of that, AD-16's closed list of markup channels contradicts AD-23, which sends faces as HTML inside JSON. And the booster's three layouts and their breakpoints contradict AD-27, while AD-16 makes the booster's system tests, which encode those breakpoints, the acceptance.

I found 5 holes: 3 high, 2 medium, plus two low notes. Each closes with a few sentences added to AD-16, AD-18 or AD-27. None needs a new AD. All must land before the trade board port starts, because that port sets the conventions for the booster.

Severity: **high** means the two ports ship structures that can't share controllers or conventions, or one port can't meet its acceptance without breaking an AD. **Medium** means a visible inconsistency or wasted work that the second port or the first later feature has to unpick. **Low** means a wording gap a builder would probably resolve the same way, but might not.

---

## F1 (high): The screen's anatomy: who owns the state, and how siblings talk

**Rule as written.** "A controller is thin: it turns a DOM event into a transition of its screen's module and reflects the result in `data-*` attributes … A rich screen splits into several controllers linked by outlets, never one controller for the screen." The state lives "in a TypeScript module in `app/frontend/lib` that touches no DOM". Separately: "A screen talks to the page chrome … only through typed `gameble:*` DOM events."

**What is unsaid:**
- which controller holds the module's instance (state) when several controllers transition it;
- which way outlets point, and whether siblings call each other;
- whether `gameble:*` events may also run between controllers of the same screen;
- who orchestrates a multi-step sequence;
- who writes which `data-*` attribute;
- which file is "the screen's module".

**Unit A: the trade board port.** It starts from `trade_board_controller.ts`, which already listens for `gameble:trade-changed` and dispatches `gameble:trade-editing`, and from `trade_send_controller.ts`, which listens for `trade-changed`. The port keeps those typed events as the glue between its new `trade-side`, `trade-picker` and `quantity-stepper` controllers, because they exist, are typed, and AD-16 only says what the *chrome* boundary is. Each controller keeps its own slice of `lib/trade_board.ts`, because that file is a bag of pure helpers today (`filterCards`, `setQuantity`, `sideCount`), not one state value. Outlets are used only where a controller needs to read another's lines.

**Unit B: the booster port.** The booster has no state module to start from: its state is about 24 `useState` pieces in `Booster.tsx`. The port builds a single state value with transitions in a new `lib/booster_screen.ts`, because "its screen's module" is singular. A `booster` root controller owns it. The `booster-canister`, `booster-card`, `booster-tray`, `booster-zoom` and `booster-banner` controllers declare `static outlets = ["booster"]` and call `this.boosterOutlet.reveal(i)`. The Légendaire sequence (jump, shake, flash, banner, navigation lock) is orchestrated by the card controller, because it starts there, and the card calls the banner's outlet directly.

**Each obeys the letter.** Both screens split into several controllers linked by outlets. Both keep a module in `lib` with no DOM. Both use `gameble:*` events. Nothing confines those events to the chrome boundary for traffic *inside* a screen.

**They clash:**
- Two incompatible controller contracts:
  - On the trade board, state is per controller and sync is by window event.
  - On the booster, state is in one root and sync is by peer calls through outlets.
  - Shared parts built later (a card zoom, a quantity stepper, a face slot) cannot serve both.
- The first booster feature after the freeze can't tell whether to add an event, an outlet call or a transition. The same goes for any later trade picker feature.
- `events.ts` keeps growing screen-internal events (`trade-changed`, `trade-editing`). That is exactly the chrome-only list AD-16 meant to keep short. `toast_controller.ts` would then have to tell chrome events from intra-screen ones.
- Peer-to-peer outlet calls in the Légendaire sequence leave no single place that knows the screen is busy. That is the "idle" the layout switch waits on (F3) and the `idle()` that `Booster.tsx` computes today from refs.
- Two controllers both write `data-*` on `.booster`. The system tests read `.booster[data-layout]`, `.booster-card[data-revealed]` and `[data-dealt]`, so a double writer becomes a race.
- "The screen's module" is ambiguous. `lib/` already holds `booster.ts`, `booster_page.ts` (touches `location`/`history`) and `booster_effects.ts` (creates spans). A reviewer can't check "touches no DOM" without knowing which file is meant.

**Proposed rule (AD-16, replacing the last sentence of the fourth bullet):**

> A rich screen (the booster, the trade board) has one root controller named after the screen (`booster`, `trade-board`) on the screen's root element, and child controllers named `<screen>-<part>` (`booster-card`, `trade-picker`). The root alone holds the instance of the screen's module, `app/frontend/lib/<screen>.ts` (one state value and pure transitions; the screen's DOM helpers live in `lib/<screen>_*.ts`). It applies every transition, runs every multi-step sequence, and writes the screen's state as `data-*` on its own element; each `data-*` attribute has one writer. A child reports an intent with a Stimulus controller event (`this.dispatch`) handled by a `data-action` on the root, and is driven only by the root, through the root's outlets to its children; children never reference each other. A `<template>` is a target of the controller that clones it. `gameble:*` events only cross a screen's edge: no controller listens to an event its own screen dispatches, and the trade board's `trade-changed` and `trade-editing` leave `events.ts` with its port.

---

## F2 (high): The markup channels contradict AD-23 and the trade faces batch

**Rule as written.** AD-16: "Markup that appears later arrives by Turbo Frame, Turbo Stream or a server-rendered `<template>` cloned by a controller; script never builds HTML." AD-23: success returns the cards, "each as its server-rendered face", in a JSON answer. AD-16 again: "The booster receives faces as server-rendered HTML."

**The code today.** Faces travel as HTML strings in JSON in two places:
- **The opening answer.** `lib/opening.ts` holds `faces: { s, m, xl }`, three sizes per card.
- **The trade picker.** It loads faces in batches from `GET /:locale/trades/faces?keys[]=…` (`faces_trades_path`, `FACES_PER_REQUEST`), via `faceLoader` in `lib/trade_faces.ts` with retries and concurrency 2. It pages 36 at a time (`PICKER_PAGE`) and filters all the player's cards in the browser ("the picker filters its cards by title and rarity without touching the selection").

Neither channel is in AD-16's list.

**Unit A: the trade board port.** It reads AD-16 strictly:
- the faces endpoint goes;
- each picker page becomes a lazy `<turbo-frame loading="lazy" src="…?page=2">`;
- `trade_faces.ts` is deleted.

Since unloaded pages can't be filtered in the browser, filtering moves to the server, and the frame reloads with the search and rarity params. The selection must now be re-applied after every frame load.

**Unit B: the booster port.** It can't follow AD-16's list without breaking AD-23. It either:
- keeps the JSON and writes `slot.innerHTML = card.faces.m`, its own helper, outside AD-16's list; or
- changes `POST /:locale/packs` to answer a Turbo Stream, which breaks AD-23's JSON contract, its error convention and the idempotent replay that returns "that pack as it was opened".

**Each obeys the letter.** A obeys AD-16 to the letter. B obeys AD-23, which is the more specific rule.

**They clash:**
- Two face-delivery paths ship: the trade picker's frames and the booster's raw `innerHTML`.
- There is no single insertion helper, so no single place to check that only server HTML is inserted.
- The trade picker loses its batched loading: one request per page instead of batches of keys.
- Filtering moves to the server for the trade picker, while the collection screen's filters stay in the browser.
- Whichever port runs second meets a precedent that contradicts its own reading.

**Proposed rule (AD-16, first bullet, replacing its last sentence):**

> Markup that appears later arrives by Turbo Frame, Turbo Stream, a server-rendered `<template>` cloned by its controller, or as server-rendered HTML inside a JSON answer. Only two answers carry HTML: the opening exchange (AD-23) and the trade faces batch (`GET /:locale/trades/faces`). One shared helper in `app/frontend/lib` places that HTML, unchanged, as the content of a `<template>` in a named slot, from which it is cloned like any other. Script builds no other HTML.

If the author prefers the trade picker on lazy Turbo Frames, the rule instead names only AD-23's answer. It must then also say that the picker filters on the server, so that the frame-based picker and a browser-filtered picker aren't both plausible.

---

## F3 (high): Layouts: one tree or one per layout, who switches, at which breakpoints

**Rule as written.** AD-16: "The server renders all markup, every layout of a screen included." AD-27: "Breakpoints are 720 and 1180 px."

**The code today.** The booster has three structurally different layouts:
- **Wide row** of `card--m` faces.
- **Narrow row** of `card--s` faces.
- **Phone:** a pile of `card--xl` faces, with an information strip, caption plate, tray and zoom.

The choice is made in script (`PHONE_QUERY` `(max-width: 719px)`, `NARROW_QUERY` `(max-width: 899px)` in `lib/booster.ts`). It is written as `.booster[data-layout]`, and the change is deferred until the island is idle (`applyLayout`).

The system tests encode all of this:
- "a width change during a reveal waits for it to end";
- "a width crossing 720px draws the same hand again: no request, nothing replayed";
- "from 720 to 899px the cards are dealt small, and step up to medium past 900px".

Meanwhile:
- `booster-layouts.css` also switches the panels at `(max-width: 1259px)`;
- `trades.css` uses 1179, 899 and 719.

So the shipped breakpoints are 720, 900, 1180 and 1260, and AD-27 names two of them.

**Unit A: the booster port.** It reads "every layout of a screen included" as one server-rendered subtree per layout: `<div data-layout-view="wide">`, `…narrow`, `…phone`, each holding the pack's slots, shown by CSS media queries at AD-27's 720 and 1180. This is the most literal reading, and it needs no layout controller.

**Unit B: the trade board port.** It reads the same sentence as one tree whose CSS covers every width, as `trades.css` does now with media queries.

**A later booster bug fix.** It follows the booster port's tests: one tree, `data-layout` written by script, 900 px.

**They clash:**
- **Acceptance.** Unit A fails acceptance even though it obeys AD-16 and AD-27:
  - a media query can't "wait for a reveal to end";
  - AD-27's 1180 breaks the 900 px test.
  
  A booster port that passes its tests has to break AD-27's breakpoint list.
- **Duplicated faces.** With one subtree per layout, every face exists three times. The `card-art` controller filters three canvases per card, which triples AD-17's worker load during the opening AD-27 budgets. The `count: 5` selector assertions hold only because they pass `visible: :all` per size class, so the tests won't catch it.
- **Faces after a layout change.** Three plausible answers:
  - the module keeps the JSON's three HTML strings (state that is markup);
  - all three sizes are rendered in each slot and CSS hides two (triple filtering again);
  - the faces are re-fetched (a request the tests forbid).
- **Mixed switching mechanisms.** Two screens switch layouts with different mechanisms (`data-layout` vs media queries) at different widths. The phone tab bar and sub-views (AD-27) then disagree with the booster about where the phone starts whenever a breakpoint moves.

**Proposed rule (AD-16, new bullet after the first):**

> A screen whose layouts differ in structure (the booster's wide row, narrow row and phone pile) renders one tree holding every layout's elements. Its root controller writes `data-layout` from AD-27's breakpoints through `matchMedia`, and changes it only when its module says the screen is idle. CSS draws those layouts from `data-layout`; a layout that differs only in arrangement uses media queries at the same breakpoints. A card shown at a different size per layout keeps one face per size as a `<template>` in its slot (F2's helper places the opening's faces there), and the root clones the one the layout needs, so the art filter runs once per face shown.

**Proposed rule (AD-27, replacing "Breakpoints are 720 and 1180 px"):**

> Breakpoints are 720, 900 and 1180 px: 720 starts the phone column, 900 the booster's wide row, 1180 the full desktop; no screen adds another (the booster's 1260 moves to 1180 with its port).

The author may prefer to drop 900 instead. In that case, the port must change the 900 px system test, which F5 otherwise forbids.

---

## F4 (medium): Copy in a split screen: variants or templates, and whose map

**Rule as written.** AD-18: "Copy is rendered by the server. A controller that composes a string (a count, an announcement) receives a scoped map of templates … as a Stimulus value."

**The code today.** The booster takes the whole `boosters.island` scope as one camelized map (`booster_strings` in `boosters_helper.rb`). The trade board takes `trades.island.strings` (`trade_island_strings`). Both maps mix composed templates ("Cards revealed: %{n} / %{total}", `pickedCards`) with fixed words that only switch:
- the state words SEALED, INVENTORY, LEGENDARY SIGNAL;
- "CLICK TO OPEN";
- the editing chip.

**Unit A: the trade board port.**
- Fixed words become server-rendered variants: hidden spans shown by CSS from the root's `data-*`, as `trades/_board.html.erb` already does for the chips.
- Only counts go through `t()`.
- The map moves to the root controller under a new `trades.strings` scope.

**Unit B: the booster port.**
- It keeps the existing map, since "a scoped map" is what AD-18 names.
- It splits the map per child controller (`boosters.canister.*`, `boosters.card.*`, `boosters.tray.*`) so each child's Stimulus value carries only its own words.
- The state word is set as `textContent` from the map.

**Each obeys the letter.** Both render copy on the server, and both give their composing controllers a scoped map as a value.

**They clash:**
- The two screens use opposite conventions for the same kind of string, and so would the first feature on either.
- Unit B's per-child maps put fixed words behind a dynamic scope. `i18n-tasks` can't see them as used, so its unused-key check goes blind on most of the booster's copy, and the CI gate AD-18 relies on weakens.
- A word needed by two children (the card title in the card's label and in the zoom) is passed twice or fetched across siblings, which F1 forbids.

**Proposed rule (AD-18, replacing the second bullet's second sentence):**

> A fixed string a screen switches between (a state word, a hint, a label) is rendered by the server in each of its variants and shown by CSS from the screen's `data-*`. Only a string that takes a count or a value at run time is a template read by the shared `t()`. A screen's templates live under one locale scope, `<screen>.strings` (`boosters.strings`, `trades.strings`), and reach its root controller as one Stimulus value; children receive composed strings from the root.

---

## F5 (medium): Port sequencing and what "the system tests are the acceptance" allows

**Rule as written.** "… are ported to this rule, the trade board first; their system tests are the acceptance. Until the last port lands, both screens take bug fixes only."

**What is unsaid:**
- Whether "first" means *starts* first or *lands* first.
- Whether a screen is ported in one change or a piece at a time, with React and Stimulus side by side.
- What a port may change in the tests.

**Unit A: the booster port.** It starts the day after the trade board port starts, which "first" allows, so F1 to F4 get decided twice. It goes piece by piece: the canister and panel move to Stimulus while the cards stay in a smaller React island. The two talk through new `gameble:*` events, exactly as `TradeBoard.tsx` and `trade_board_controller.ts` talk today, and those events stay.

**Unit B: the trade board port.** It ports the whole screen in one change and edits the tests freely: they are "the acceptance", but nothing says they are fixed.

**The test that can't survive unchanged.** "an island whose code does not load leaves a message and a reload of the whole page" blocks `*/Booster-*.js` and expects `.booster--failed[role=alert]`. With Stimulus bundled, that chunk no longer exists. One port deletes the test. The other code-splits its controllers into a lazily imported `Booster-*.js` chunk just to keep it green.

**They clash:**
- The two ports ship in two sequences with different leftovers: bridge events in `events.ts`, a lazy chunk kept only for one test.
- "Acceptance" means "unchanged" for one screen and "rewritten" for the other.
- A bug fixed in `Booster.tsx` during the port, which the freeze allows, doesn't reach the port.

**Proposed rule (AD-16, last bullet, after "the trade board first"):**

> The trade board's port lands before the booster's starts, and the booster follows the conventions it set. Each screen is ported in one change that removes its island whole; no screen runs React and Stimulus side by side, and no `gameble:*` event is added to bridge them. A port keeps its screen's system tests as they stand, selectors and wording included. It may only replace the test of the island's own loading failure with the promise that remains, the screen's form working without JavaScript, and rename locale scopes per AD-18. A bug fixed in an island while its port is open is fixed in the port too, with a test.

---

## Low notes

- **L1: effect elements built by script.** `trade_swap_controller.ts` and `lib/booster_effects.ts` (`spark`) create empty `aria-hidden` spans for confetti, rings and sparks, then remove them. "Script never builds HTML" lets one port keep them and pushes another into a server-rendered pool of particle `<template>`s. Both work, but the second costs DOM for nothing. Close it with one clause in AD-16: *"An empty, `aria-hidden` effect element a controller creates and removes within one animation is not markup."*
- **L2: browser storage.** The trade draft lives in `localStorage` (`lib/trade_draft.ts`, and a system test requires it). The booster's way back uses `?pack=` in the URL (`booster_page.ts`). The trail uses `sessionStorage`. AD-16 says interaction state lives in a module that "touches no DOM" but doesn't say where storage access sits. The existing modules already inject storage, so builders will probably converge. If the author wants it explicit, add to AD-16: *"Browser storage holds only interaction state, read and written by the screen's module through an injected storage."*

## Considered and dropped

- **A feature built in React while its screen is ported.** The port freeze added to AD-16 on 2026-10-22 closes it.
- **The module's file naming (snake vs kebab).** `lib/` is snake_case apart from the `collection-grid` test file. F1's `lib/<screen>.ts` settles the only name that matters.
- **Turbo cache and outlets reconnecting on restore.** AD-27 already says booster and trade pages are never cached by Turbo.
- **The navigation lock.** It already crosses to the chrome through `gameble:navigation-locked` and `navigation_lock_controller.ts`; both ports would reuse it.
