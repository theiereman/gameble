# Review: reality check of the 2026-10-22 amendment (AD-16, Hotwire only)

Independent reviewer, 2026-10-22. Lens: was every committed technical claim of the amendment checked against reality, or asserted from memory? Scope: the working-tree diff of `architecture-gameble.md` (AD-16 rewritten; AD-18, AD-23, AD-27, the conventions, the Stack table, the tree and the capability map adjusted). The spine was not edited.

Read: `package.json`, `package-lock.json`, the installed `node_modules/*/package.json`, `Gemfile`, `Gemfile.lock`, `.ruby-version`, `.tool-versions`, `node_modules/@hotwired/stimulus/dist/stimulus.js` and its `dist/types/core/outlet_*.d.ts`, `config/initializers/content_security_policy.rb`, `vite.config.ts`, `vitest.config.ts`, `tsconfig.json`, `app/frontend/entrypoints/application.ts`, `app/views/layouts/_head.html.erb`, the controllers that already clone `<template>` (`toast`, `landing_feed`, `moving_cards`), `live_refresh_controller.ts`, the views that call `turbo_exempts_page_from_cache` and `turbo_refreshes_with`, the React islands under `app/frontend/components/`, and `test/system/booster_test.rb` and `trades_test.rb`. Registry queries (`npm view`, `gem info -r`) on 2026-10-22.

**Verdict: pass with fixes.** The mechanisms the amendment relies on exist in the installed versions: Stimulus 3.2.2 ships outlets, Turbo 8.0.23 ships Frames, Streams and morphing, and the production CSP does not get in the way of `<template>` cloning, CSSOM custom properties or the Web Animations API. The amendment adds no dependency, so its Stack edits are only the "until the last port" markers. Three things were not checked, though. The edited `@vitejs/plugin-react` row still shows a version that is not installed. Outlets have not been used anywhere in the app yet, and the rule omits their two practical constraints. And the list of channels for late markup leaves out the one the booster uses today (HTML inside AD-23's JSON response). The rule is also silent on Turbo morph refreshes, which already run on the trade screen and erase state reflected in `data-*` attributes.

---

## What holds

- **Stimulus outlets exist and work in the installed version.** `@hotwired/stimulus` is pinned and installed at 3.2.2 (2023-08-07, still the latest on npm). `dist/stimulus.js` implements `OutletObserver`, `OutletSet` and `OutletPropertiesBlessing`. The blessing provides `xOutlet`, `xOutlets`, `xOutletElement(s)`, `hasXOutlet` and the `xOutletConnected`/`xOutletDisconnected` callbacks. The attribute is `data-<host>-<outlet>-outlet="<css selector>"` (`defaultSchema.outletAttributeForScope`). Version 3.2.2 carries the ordering fix: the `xOutlet` getter calls `router.proposeToConnectScopeForElementAndIdentifier`, so a host reading an outlet in `connect()` gets it even if the outlet element comes later in the DOM. When an outlet controller connects, its `OutletObserver.start()` refreshes its dependent host contexts. Controllers are registered eagerly (`import.meta.glob(..., { eager: true })` through `stimulus-vite-helpers`), so the outlet dependency map built from `router.modules` is complete at start.
- **`<template>` cloning and the CSP.** Cloning a template's `content` is DOM work that CSP does not govern. The production policy (`script-src 'self'`, nonces on `style-src` only, no `'unsafe-inline'`) does block `style` attributes parsed from markup, and AD-16 already forbids those in server HTML, template content included. `element.style.setProperty` (CSSOM) and `element.animate()` (Web Animations) are not subject to `style-src`, so the "custom properties set by a controller; CSS and WAAPI draw" model fits. Three controllers already clone server templates (`toast_controller.ts:90`, `landing_feed_controller.ts:54`, `moving_cards_controller.ts:83`), and their system tests run under this policy (it is enforced in every environment, test included).
- **Turbo Frames and Streams and the CSP.** Streams arrive over fetch or the cable (`connect-src` derives the cable origin from `PUBLIC_URL`). Turbo re-activates `<script>` elements inside streamed content by copying the `csp-nonce` meta. That nonce is valid only for `style-src`, so streamed inline script stays blocked, which matches "script never builds HTML". The progress bar's `<style>` gets its nonce the same way (documented in the initializer), and the nonce is the session id, which stays stable across Turbo visits.
- **Turbo cache.** "Booster and trade pages are never cached by Turbo" is implemented: `turbo_exempts_page_from_cache` in `boosters/show`, `trades/_screen`, `pages/home`, `pages/more` and `friends/show`. Both rich screens the amendment targets are therefore exempt, so cloned nodes and reflected `data-*` state cannot be restored from a stale snapshot there. The `data-turbo-preview` guard pattern already exists in six controllers.
- **Stack rows that match the lockfiles.** These rows match: React, react-dom, @types/react and @types/react-dom (19.3.0); turbo-mount gem and npm (0.4.4); turbo-rails gem (2.0.23) and npm (8.0.23); stimulus-rails (1.3.4); @hotwired/stimulus (3.2.2); stimulus-vite-helpers (3.1.0, no peer dependencies; it stays after the port because `application.ts` registers controllers with it); vite_rails (3.11.1, with vite_ruby 3.11.1); vite-plugin-ruby (5.2.5 installed); TypeScript (7.0.2); Ruby 4.0.7; Node 24.15.0; Rails, Puma, Kamal, Solid*, Mission Control, ViewComponent, dry-operation, Rails Event Store, Packwerk, packs-rails and Capybara.
- **"Interaction state in a DOM-free module tested by Vitest"** matches the setup: `vitest.config.ts` runs `environment: 'node'` over `app/frontend/**/*.test.ts`, and no DOM emulator is installed, so a module that touches the DOM fails its own tests.

---

## Findings

### F1 (Medium): the amended `@vitejs/plugin-react` row was edited without checking the installed version, and the Stack header still claims a 2026-10-02 verification

The amendment edited the row `@vitejs/plugin-react | 6.1.1, until the last port`. The installed and pinned version is **6.1.2**: `package.json` pins `"@vitejs/plugin-react": "6.1.2"`, and the lockfile and `node_modules` agree. This is the clearest sign that the edited rows were not checked against the lockfiles. Other rows have drifted too, from earlier upgrades:

| Row | Spine | Lockfile / installed |
| --- | --- | --- |
| @vitejs/plugin-react | 6.1.1 | 6.1.2 |
| Vite | 8.3.2 | 8.3.4 (`^8.3.4` range) |
| Vitest | 5.0.3 | 5.0.4 |
| pg | 1.6.3 | 1.7.0 |
| Thruster | 0.1.26 | 0.1.27 |
| selenium-webdriver | 4.50.0 | 4.51.0 |

`vite` and `vite-plugin-ruby` are also caret ranges in `package.json`, while every other npm dependency is pinned exactly. For those two, the table records a floor, not a pin. The header line "Verified against the RubyGems and npm registries on 2026-10-02" is no longer true of the table.

**Fix:** set the six rows to the lockfile versions. Change the header to "Matches `Gemfile.lock` and `package-lock.json` as of 2026-10-22". Either pin `vite` and `vite-plugin-ruby` exactly like the other dependencies, or write their rows as `^8.3.4` and `^5.2.5`.

### F2 (Medium): the channels for late markup leave out AD-23's JSON-borne faces, which the booster port depends on

AD-16 now says markup that appears later arrives "by Turbo Frame, Turbo Stream or a server-rendered `<template>` cloned by a controller; script never builds HTML." AD-23, which the same amendment touched, still has the opening return JSON with "each [card] as its server-rendered face". Today the booster inserts those faces with `dangerouslySetInnerHTML` (`BoosterCard.tsx:146`). The trade board does the same for its faces and static sides (`TradeBoard.tsx:197`, `221`). A Stimulus port has to put a JSON string of HTML into the DOM, through `innerHTML`, `<template>.innerHTML` or `Range.createContextualFragment`, and none of those is one of the three named channels. One session will read "script never builds HTML" as allowing it, because the HTML is server-built. Another will move the opening to a Turbo Stream response and break AD-23's idempotent-replay contract. The CSP does not decide the question: without Trusted Types, `innerHTML` of style-free markup is allowed.

**Fix:** decide one of two options, and state it in both AD-16 and AD-23:
- (a) AD-16 adds a fourth channel: "or server-rendered HTML carried in an operation's JSON response (AD-23), parsed into a `<template>` and cloned." The face markup must carry no `style` attribute and no script.
- (b) AD-23's success response becomes a Turbo Stream with the pack data as stream-target attributes. AD-23 must then say how a replayed idempotency key is answered.

Option (a) changes nothing on the server and is the smaller change.

### F3 (Medium): the outlet rule omits the constraints a multi-controller screen runs into, and outlets are not used anywhere in the app yet

`grep` finds no `static outlets` and no `-outlet=` attribute in `app/` or `packs/`, so "split into several controllers linked by outlets" has not been tried in this codebase. These behaviours follow from the 3.2.2 source:

1. **Outlet selectors are document-wide.** `OutletSet` queries `documentScope`, and `SelectorObserver` watches `document.body`. A booster controller could take an outlet in the top bar or the toast region, which bypasses AD-16's "a screen talks to the page chrome only through `gameble:*` events". Two instances of a screen part could also cross-wire.
2. **`xOutletConnected` runs before the host's `connect()`.** `Context.connect()` starts `outletObserver` before it calls `controller.connect()`. An outlet that is already connected therefore fires the callback first, so state the host sets up in `connect()` is not there yet. State must be built in `initialize()`.
3. **`this.xOutlet` throws** when no element matches or the element has no matching controller. Optional peers need `hasXOutlet`.
4. **Outlets are one-way.** The outlet controller cannot see its host. Peer-to-peer replies need either an outlet declared on each side (a cycle) or events.
5. **A replaced outlet is a new controller.** When a Turbo Stream `replace` or a morph swaps a peer's element, `xOutletDisconnected` and `xOutletConnected` fire with a new instance. A host that cached the old reference holds a dead controller.
6. **Typing an outlet requires the peer's class.** `declare readonly fooOutlet: FooController` needs a named, exported class. Today's controllers are `export default class extends Controller`, anonymous.

**Fix:** add one line to AD-16: "Outlets link controllers inside one screen's root only, by a selector scoped to that root (`#<screen-token> [data-controller~=…]`), never to the chrome; a host builds its state in `initialize()`, reads optional peers through `has…Outlet`, and holds no outlet reference across a disconnect; the screen module, not the outlets, is the shared state." Have the trade-board port, which comes first, prove the pattern before the booster copies it.

### F4 (Medium): morph refreshes erase state reflected in `data-*` attributes, and the rule is silent on them

The trades screen refreshes with `Turbo.session.refresh(..., { method: "morph" })` (`live_refresh_controller.ts`), and `pages/home` declares `turbo_refreshes_with method: :morph`. Idiomorph rewrites attributes to match the new server HTML. So a morph during an interaction strips the `data-*` attributes and controller-set `style` custom properties that AD-16 makes the reflection of module state. The module keeps its state and the DOM no longer shows it. The repo already has the fix, applied case by case: the `LIVE_REFRESH_HOLD` attribute defers the refresh, and `toast_controller.ts` cancels morphs with `turbo:before-morph-element`. The amendment makes `data-*` reflection the general model and says nothing about it.

**Fix:** add to AD-16 or AD-27: "While a screen module holds an interaction in progress, the screen holds live refreshes (the live-refresh hold attribute); after a morph, a controller re-applies its module's state to the attributes it owns."

### F5 (Low): what "leaving the stack" removes besides four packages, and one acceptance test that cannot survive the port

The last port also has to remove:
- `vite_react_refresh_tag` (`layouts/_head.html.erb:40`);
- the `react()` plugin in `vite.config.ts`;
- `"jsx": "react-jsx"` in `tsconfig.json`;
- the `turbo-mount` **gem** (the Stack names "Turbo Mount" without saying it is both a gem and an npm package);
- `app/frontend/components/`, which the amended tree already drops, so the tree describes the end state, not today.

The development CSP's `script-src 'unsafe-inline' 'unsafe-eval'` is justified in the initializer by "React refresh's inline preamble". Once React is gone, that justification is gone too, and the dev policy should be tightened.

"Their system tests are the acceptance" cannot hold for `booster_test.rb:684` ("an island whose code does not load leaves a message…"). That test exists because of the React lazy chunk and its error boundary.

**Fix:** add these items to the removal sentence. Add "except the tests of island-only failure modes, which are replaced or removed".

### F6 (Low): the CSP as AD-27 describes it differs from the initializer (prior drift, not introduced here)

| AD-27 | `content_security_policy.rb` |
| --- | --- |
| `font-src 'self'` | `font_src :self, :data` |
| `img-src` lists the Steam hosts | `img_src :self, :data` plus the Steam hosts |
| "runs report-only for one release first" | enforced in every environment |
| `connect-src` names "the cable's `wss:` origin" | derived from `PUBLIC_URL` (`ws` or `wss`) |

`vite.config.ts` also says an inlined font "would be refused by the Content-Security-Policy's font-src 'self'", which the initializer now contradicts. None of this blocks the amendment.

**Fix:** align the AD-27 sentence with the initializer, or remove `:data` from `font-src`, which `vite.config.ts` already makes unnecessary.

### Out of lens

`Gemfile` (lines 42 and 46) and `app/frontend/entrypoints/application.ts` (lines 1 and 29) carry "AD-16" in comments, against the repo policy "never write planning ids in code … or config". The port will touch both files and can drop them.
