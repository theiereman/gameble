# Rubric and reconcile review — spine update 2026-10-22 (AD-16 Hotwire only)

- **Spine:** `architecture-gameble/architecture-gameble.md` (uncommitted diff of 2026-10-22: AD-16 rewritten, AD-18 copy bullet, AD-23 wording, AD-27 reduced-motion line, Consistency Conventions accessibility row, Stack table, source tree, capability map, pack table web-layer row).
- **Context:** `.memlog.md`, the four 2026-10-22 entries (question, two directions, decision).
- **Codebase checked:** `app/frontend/entrypoints/application.ts`; `app/frontend/components/*.tsx` (Booster and its parts, TradeBoard, TradePicker, hooks); every `app/frontend/controllers/*.ts` by grep, with `trade_board_controller.ts`, `showcase_order_controller.ts`, `feed_announcer_controller.ts`, `reserve_chip_controller.ts` read; `app/frontend/lib/` (`i18n.ts`, `events.ts`, `booster.ts`, `booster_page.ts`, `booster_effects.ts`, `glitter.ts`, `trade_board.ts`, `trade_draft.ts`, `trade_faces.ts`, `live_refresh_hold.ts`); `vitest.config.ts`; `package.json`; `app/helpers/boosters_helper.rb`; `app/views/boosters/show.html.erb`, `app/views/trades/_board.html.erb`, `_draft_board.html.erb`; `test/system/booster_test.rb`, `test/system/trades_test.rb`.
- **Other planning docs grepped:** `spec-gameble/*.md`, `ux-gameble/*.md`, root `AGENTS.md`.

## Verdict

**Conditional pass.** The direction is sound and mostly ratifies what the codebase already does: pure, DOM-free `lib/` modules tested by Vitest in a `node` environment (`booster.ts`, `trade_board.ts`, `opening.ts`, `celebration.ts`), state reflected in `data-*` attributes (`.booster-card[data-dealt]`), Stimulus `templates: Object` values read by `t()`, WAAPI choreography (`booster_effects.ts`, `trade_swap_controller.ts`), and `gameble:*` events toward the chrome. But the new rule leaves four divergence points open that the first port (the trade board) and the booster port hit on day one, and one of them contradicts an adopted AD outright:

1. The three allowed channels for late markup exclude HTML carried in JSON, which AD-23's opening answer and the picker's faces endpoint both use.
2. Intra-screen communication: the rule says outlets, the code uses `gameble:trade-changed` / `gameble:trade-editing` between the trade island and its Stimulus neighbours, and nobody owns the screen module instance.
3. Initial screen data: the "props" bullet was deleted with no replacement, so a porter will turn `booster_props` into one JSON Object value.
4. The transition period: nothing says what happens to a booster feature or fix before its port.

Fix findings 1 to 4 before the porting epic is sliced; 5 to 9 in the same pass; the low findings when convenient.

## Findings

### 1. CRITICAL — "Markup that appears later arrives by Turbo Frame, Turbo Stream or a server-rendered `<template>`" contradicts AD-23 and the trade picker's faces endpoint

- **Where:** AD-16 bullet 1 ("script never builds HTML"); AD-16 bullet 2 ("The booster receives faces as server-rendered HTML"); AD-23 ("Success returns … its 3 or 5 cards in drawn order (each as its server-rendered face …)", JSON); `lib/trade_faces.ts` (`fetchFaces`, JSON `{ faces: { key: html } }`, 36 per page); `BoosterCard.tsx:146`, `BoosterZoom.tsx:152`, `TradePicker.tsx:360`, `TradeBoard.tsx:197,221` (all `dangerouslySetInnerHTML` of server HTML).
- **Problem:** The opening answer is JSON carrying face HTML strings, and the picker pages faces in through a JSON endpoint. Neither is a Frame, a Stream or a `<template>`, so a Stimulus port must either assign `innerHTML` from JSON (which reads as "script builds HTML") or change the endpoint (which AD-23 forbids). Two porters will split here. There is a second split inside the booster: a reloaded page with an opened pack (`booster_props(opened:)`, "the opening exchange's answer for an opened pack the island shows dealt") will now be server-rendered markup, while a fresh opening inserts faces from JSON. That gives two render paths for the same dealt state, which is the "a card face drawn two ways" that AD-16 prevents, in a new form.
- **Fix (the author picks one and writes it into AD-16 and AD-23):**
  - (a) **HTML fragment in the answer:** AD-16 bullet 1 adds a fourth channel: "or as an HTML fragment rendered by the same ViewComponent that renders it on page load, carried in an operation's JSON answer and inserted whole by a controller (AD-23)". AD-23 then says: "each card's face, back and label as one fragment rendered by the dealt-card component that the booster page renders for an opened pack". The picker's faces endpoint stays and is named as allowed.
  - (b) **Turbo Stream answer:** AD-23's success answer becomes a Turbo Stream (`Accept: text/vnd.turbo-stream.html`) that fills `<template>` slots with the dealt cards, plus one JSON `<script type="application/json">` or `data-*` payload for counts, bank and sets. Failures keep the JSON error convention. The picker pages faces by lazy Turbo Frames (`loading="lazy"`, one frame per page of 36). This is purer but rewrites a tested protocol (idempotency replay, 39 booster system tests).
  - Recommendation: (a). It keeps AD-23's tested protocol and closes the two-path risk by naming the component.

### 2. HIGH — Intra-screen communication and ownership of the screen module are unspecified; the rule contradicts the code that already exists

- **Where:** AD-16 bullet 4 ("splits into several controllers linked by outlets, never one controller for the screen"); bullet 5 ("A screen talks to the page chrome … only through typed `gameble:*` DOM events"); memlog decision ("gameble:* events stay, only for a screen to talk to the chrome"); `lib/events.ts` (`gameble:trade-changed`, `gameble:trade-editing`); `TradeBoard.tsx:149,154`; `trade_board_controller.ts:42,57,75`; `trade_send_controller.ts:13`.
- **Problem:** The trade screen is already split, into the React island plus the `trade-board`, `trade-send` and `trade-swap` controllers, and they talk through two `gameble:*` events that are not chrome events. No controller in the app uses outlets today. The spine text does not forbid intra-screen `gameble:*` events (only the memlog does), so after the port one builder keeps `trade-changed` and another replaces it with outlets. Separately, "a transition of its screen's module" does not say which controller holds the module instance. With several controllers per screen, the options diverge: each controller keeps a copy (state drift), a root controller owns it, or a module-level singleton (a "global client store" by another name, forbidden by bullet 7).
- **Fix:** Replace bullet 4's last sentence with: "A rich screen (the booster, the trade board) has one screen controller on its root element that owns the only instance of its module and is the only caller of its transitions; region controllers (stage, tray, zoom, picker, stepper, …) reach it through an outlet and re-read state from it. Controllers of one screen never talk through `gameble:*` events; those are for the chrome only." Add to the port bullet: "`gameble:trade-changed` and `gameble:trade-editing` leave `lib/events.ts` with the trade board's port." Give a split criterion that a reviewer can check: "a controller owns one region of the screen's markup and its targets lie inside that region".

### 3. HIGH — Initial screen data has no rule since the props bullet was removed

- **Where:** deleted bullet "A component receives its initial data and its strings as props"; AD-18 new bullet ("receives a scoped map of templates … as a Stimulus value"); `app/helpers/boosters_helper.rb#booster_props` (bank, season, next pack size, opened pack, strings); `app/views/trades/_board.html.erb` (`turbo_mount("TradeBoard", props: island)`).
- **Problem:** The booster's props are a large JSON object of data plus strings. The new rule says that markup is server-rendered and that count templates travel as a Stimulus value, but nothing says where state such as the bank count, the server time, the opened pack, the per-tier counts or the card back comes from. The easiest port is `data-booster-props-value="<%= booster_props(...).to_json %>"`, which keeps the React-era architecture, makes the controller fat and gives a second source of truth beside the rendered markup. Existing controllers take typed scalar values (`String`, `Number`, `Boolean`), and `Object` only for template maps. That practice is the one to ratify.
- **Fix:** Add a bullet: "A controller reads its initial state from the server-rendered markup: typed scalar Stimulus values on its element and `data-*` attributes on its targets. An `Object` value holds only a template map (AD-18). No controller receives the screen's state as one JSON value. Text that does not depend on a client-side count is in the markup (visible, hidden or in a `<template>`), not in a value." In AD-18, add "single strings as `String` values" to match `showcase_order_controller.ts` and `reveal_demo_controller.ts`.

### 4. HIGH — The transition period is not ruled: what happens to a booster or trade feature before its port?

- **Where:** AD-16 port bullet; memlog direction ("booster and trade board are central and will keep gaining features").
- **Problem:** AD-16 is `[ADOPTED]` and now forbids a client view library, while the booster stays React until the second port. A session that builds a booster feature or fixes a bug in the meantime cannot follow the rule. It will either add React code, which grows the port, or port the part it touches, which yields a half-React screen that the rule does not describe. Two sessions will choose differently.
- **Fix:** Add to the port bullet: "Until its port, an island keeps its Turbo Mount contract; it takes bug fixes only, and a new feature on the booster or the trade board is built after or as part of its port. No new React component is written." Make the porting epic's ordering carry this: a ticket that touches a not-yet-ported island depends on the port ticket.

### 5. MEDIUM — "script never builds HTML" and "reflects the result in `data-*` attributes" contradict the existing code and the accessibility floor

- **Where:** AD-16 bullets 1 and 4; `lib/glitter.ts:95-106` (glitter spans, required by AD-27's Légendaire glitter), `lib/booster_effects.ts:40`, `controllers/trade_swap_controller.ts:90`, `controllers/bonus_arc_controller.ts:84` (flyer div plus a cloned icon), `lib/card_art/plain.ts:46` (canvas), `controllers/toast_controller.ts:35` (clones an incoming node); `trade_board_controller.ts#show` (toggles `hidden` and a class), many `textContent` writes to live regions (`feed_announcer`, `share`, `showcase_order`, `reserve_chip`).
- **Problem:** Read literally, bullet 1 forbids six existing modules and the particles the booster's choreography needs (rings, sparks, glints), and bullet 4 forbids setting `hidden`, `inert`, `aria-*`, focus and live-region text. The accessibility floor requires all of these. Porters will either break the rule silently or stretch `data-*` and CSS to emulate `hidden` and `aria-*`, both of which fail accessibility. Neither bullet can be enforced without tooling: there is no ESLint and no CI grep.
- **Fix:** Bullet 1: "script never builds content: it creates no element that carries text or semantics; it may create empty decorative nodes (particles, glints, flyers, canvases) marked `aria-hidden`, clone a server `<template>` or node, and set the text of a live region or a counter." Bullet 4: "reflects the result in `data-*` attributes, and in `hidden`, `inert`, `aria-*`, focus and live-region text where the accessibility floor needs them; never in inline style other than custom properties." Add a `bin/ci` grep that fails on `innerHTML`, `outerHTML`, `insertAdjacentHTML` and `DOMParser` under `app/frontend` (with the one place allowed by finding 1(a), if chosen).

### 6. MEDIUM — "every layout of a screen included" does not settle how the booster switches between desktop and phone

- **Where:** AD-16 bullet 1; `lib/booster.ts:303-307` (`PHONE_QUERY`, `NARROW_QUERY`, `layoutFor`); `lib/booster_page.ts#readLayout`; `Booster.tsx:971` (rebuild on a media-query change); `EXPERIENCE.md:545` ("the capsule stage re-lays dealt cards in place without replaying"); `review-feasibility.md` H3 ("two choreographies").
- **Problem:** The phone layout (a pile, a tray, a plate, swipe) and the desktop row are structurally different. "The server renders every layout" allows either one DOM restyled by CSS breakpoints or two trees with one hidden. With two trees the dealt faces, the live region and the focus targets exist twice, and a resize must move the reveal state between trees. The JS layout switch (`layoutFor`) has no stated place.
- **Fix:** Add: "A screen has one DOM for every layout; CSS breakpoints place it, and a controller reads the active layout only to choose a choreography (`lib/booster.ts#layoutFor`), never to render or move markup. A layout-only element (the phone tray) is present in the markup and hidden by CSS on other layouts."

### 7. MEDIUM — Interaction state that outlives the page has no status: the trade draft and the remembered opened pack

- **Where:** AD-16 bullet 3 and Prevents ("game state held only in the browser"); `lib/trade_draft.ts` (`localStorage`, `gameble:trade-draft:<key>`, checked by `trades_test.rb:294`); `lib/booster_page.ts#rememberPack` (opened pack token in the URL, `pack` and `celebration` params).
- **Problem:** "Only the state of an interaction in progress … lives in the browser, in a TypeScript module" does not cover state persisted in `localStorage` or in the URL. A porter reading "game state held only in the browser" may move the trade draft to the server (a new table and operation) while another keeps `localStorage`. The memlog also says "the trade picker can be mostly server-driven", which pushes the same way.
- **Fix:** Name both in bullet 3: "An unsent trade draft and the opened pack's token may persist in `localStorage` and the URL; they are a convenience the server never trusts, and losing them loses no game state." If the author wants drafts server-side, say so here, because it is a new operation and a new table.

### 8. MEDIUM — Live updates arriving mid-interaction are not ruled; the existing hold mechanism is not ratified

- **Where:** AD-16 bullet 3 (state in a module held by a controller); `lib/live_refresh_hold.ts` (`data-live-refresh-hold`), `lib/stream_hold.ts`, `trade_board_controller.ts:39,88` (`holdLiveRefresh` while editing); AD-27 (Turbo caching); `gameble:trades-updated`.
- **Problem:** Once a screen's state lives in a controller rather than in a React tree that Turbo does not touch, a Turbo Stream or morph that replaces the screen's root disconnects the controller and drops the interaction (a half-built counter-proposal, a reveal in progress). The code already solves this with a hold attribute, but the rule does not say so, and the booster port may solve it a second way.
- **Fix:** Add: "While an interaction is in progress, the screen controller sets `data-live-refresh-hold` (`lib/live_refresh_hold.ts`); a stream or refresh aimed at a held screen is deferred until it is released."

### 9. MEDIUM — "their system tests are the acceptance" is not literally achievable

- **Where:** AD-16 port bullet; `test/system/booster_test.rb:684` ("an island whose code does not load …" blocks `*/Booster-*.js` and asserts the error boundary and the `boosters.island.island_failed` key); `application.ts` (booster lazy-loaded behind `BoosterErrorBoundary`).
- **Problem:** At least one booster test asserts React-specific machinery: the lazy chunk, the error boundary and its locale keys. The rule says nothing on whether the booster's controllers stay lazy-loaded (`registerControllers` is an eager glob) or what a failed load looks like after the port. The porter will either delete the test or rebuild lazy loading, without a rule to say which.
- **Fix:** Add: "Tests that assert island mechanics (the lazy chunk and its failure message) are rewritten for the port's loading strategy, not deleted unreviewed; the booster's controllers are [eagerly loaded | loaded with the booster page only], and the server form without JavaScript stays the fallback."

### 10. LOW — AD-18's rewritten bullet describes a `t()` the code does not have

- **Where:** AD-18 bullet 2 ("`one`/`other` forms and `%{n}` placeholders"); `lib/i18n.ts` (`zero`/`one`/`other`, named placeholders `%{count}`, `%{number}`); AGENTS.md ("French plural keys need a `zero` form").
- **Fix:** "… with `zero`/`one`/`other` forms and named `%{…}` placeholders, read by one shared `t()` (`lib/i18n.ts`) that picks `zero` for 0 when present, `one` for 1, else `other`."

### 11. LOW — Example names that do not exist, and Stack drift

- **Where:** AD-16 bullet 4 lists `hotkeys` (no `hotkeys_controller.ts`); bullet 5 lists `trade-badge` and `back-unlocked` (not in `lib/events.ts`). Stack: `@vitejs/plugin-react` 6.1.1 against 6.1.2 in `package.json`, Vitest 5.0.3 against 5.0.4. All of these predate the amendment and were carried forward.
- **Fix:** Use real names (`navigation-locked`, `opening-revealing`, `trades-updated`) or mark examples as planned, and align the two version rows.

### 12. LOW — Code comments still describe islands and props

- **Where:** `application.ts:1`, `lib/i18n.ts:1-2` ("through props"), `lib/events.ts` (several "booster island"), `lib/booster.ts:1` ("no React"), `app/views/shell/_rarity_counter.html.erb`, `_reserve_chip.html.erb`, locale keys `boosters.island.*`.
- **Fix:** Not a spine change: put a cleanup step in each port ticket's acceptance ("no `island` or `props` wording remains in the ported code, its comments or its locale keys").

## Other sections of the spine

- AD-18, AD-23, AD-27, the conventions row, the Stack table, the source tree, the pack table and the capability map are consistent with the new AD-16, apart from findings 1 and 10.
- AD-28 still cites `Card.tsx`. It is a record of work already done ("give way to AD-16's single face") and contradicts nothing; leave it.
- No other AD mentions islands, React, props or Turbo Mount (grep of the whole spine).

## Other planning docs that now contradict AD-16

| File:line | Text | Fix |
| --- | --- | --- |
| `AGENTS.md:6` | "Hotwire with TypeScript Stimulus controllers and one React island" (already wrong: there are two) | "Hotwire with TypeScript Stimulus controllers; the booster and the trade board are React islands being ported to Stimulus" (drop the clause after the last port) |
| `AGENTS.md:30` | "Islands talk only through the `gameble:*` events …" | "A screen talks to the page chrome only through the `gameble:*` events declared in `app/frontend/lib/events.ts`; script never builds content; server HTML carries no `style` attribute." This line is loaded into every session, so it matters most. |
| `spec-gameble/spec-gameble.md:217` | "with React components embedded for the pack opening and the trade board" | "server-rendered with Hotwire (Turbo and Stimulus), no client-side view library" |
| `ux-gameble/ux-gameble.md:66` | "3. **Islands (AD-16):** booster … and trade board; … DOM event contract between islands and server-rendered chrome" | Reword as "Rich screens (AD-16)" or mark the "For the architecture" list as absorbed on its date |
| `ux-gameble/ux-gameble.md:74` | "11. **i18n in islands**" | "i18n in controllers", or the same absorbed note |
| `ux-gameble/EXPERIENCE.md:655` | "opened with `showModal()`, in Stimulus and React" | "in every controller" |
| `ux-gameble/EXPERIENCE.md:665` | "a Stimulus controller over server-rendered card faces, not the booster island" | "not the booster's controllers" (the intent, not posting packs, stands) |

Dated review records (`ux-gameble/review-feasibility*.md`, `ux-gameble/validation-report.md`, `architecture-gameble/reviews/*`) also mention islands and Turbo Mount. They are historical and should be left as they are.

## Checklist answers

- **Does AD-16 fix the real divergence points of the two ports, and miss none?** It fixes the big ones: no view library, a single face renderer, server-held game state, thin controllers, a split screen, and the chrome contract. It misses five: late markup in JSON (1), the intra-screen channel and module ownership (2), initial data (3), the transition period (4), and layout switching (6). Persistence (7), live-update holds (8) and the loading strategy (9) are smaller misses.
- **Is every bullet enforceable, and does it prevent its stated divergences?** "No client view library": yes, through `package.json` after the last port. "One face renderer" and "no `style` attribute": yes, as today. "DOM-free module tested by Vitest": yes, since `vitest.config.ts` runs in `node`, so DOM access throws in tests. "Script never builds HTML" and "reflects in `data-*`": not as worded (5), and unenforced without a grep. "Thin" and "never one controller for the screen": not checkable without the split criterion of finding 2. "`gameble:*` to the chrome": checkable in `events.ts` once intra-screen events are retired (2). "System tests are the acceptance": not literal (9).
- **Does it ratify the codebase?** Mostly yes: pure `lib/` modules, `data-*` state, `templates: Object` values with `t()`, WAAPI, and a pre-split trade screen. It contradicts the code in five places: the intra-screen `gameble:*` events (2), decorative `createElement` and `hidden`/`aria-*` writes (5), the faces JSON (1), the `localStorage` draft (7), and AD-18's placeholder wording (10).
- **Do other ADs or sections contradict it?** AD-23 does (1). Nothing else in the spine does; AD-28's `Card.tsx` mention is historical.
