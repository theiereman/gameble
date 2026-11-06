---
title: 'Native top bar for the iOS and Android apps'
type: 'feature'
ticket: ''
created: '2026-11-06'
status: 'built'
baseline_revision: '91c7c81e07290cd1fb4b7940cffa294b7bb07adf'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - '_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md (section Responsive & Platform, Native apps, under the worktree named in Verification)'
  - '_bmad-output/initiative-gameble/ux-gameble/DESIGN.md (section Native apps top bar, under the same worktree)'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** In the apps the top bar is part of every web page: its contents differ per screen, it is redrawn on each navigation and its back button arrives after the page has loaded.

**Approach:** One native bar per app, outside the pages, as specified in EXPERIENCE.md (Responsive & Platform, Native apps). The web header stays in the DOM, invisible, as the source of counts and as the host of the server-rendered bell and menu panels.

## Boundaries & Constraints

**Always:** the back button comes from the native stack, never from the page. The web bar disappears only for an app that declares the `top-bar` component and a signed-in player, so older test builds and browsers keep today's bar. Sheets presented natively cover the bar. Bar height equals `--topbar-height` (56).

**Never:** merge to develop. Change a browser's bar. Fetch counts natively with a separate cookie store. Build bell or menu contents natively. Keep the page's own back markup in the app.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Push | Link in a page | Left turns to "◀ PREVIOUS" as the screen opens, before it loads | Previous label unknown: "◀ RETOUR" |
| Tab change | Tap a tab | Bar stays; left follows that tab's stack; bar shown | None |
| Scroll | Down then up | Hides then returns; panels close when it hides | At top or on a screen with no scroll: shown |
| Capsule spent | Any screen or tab | Counter updates from the visible page | Reports from pages not on screen are ignored |
| Cold start | No page loaded yet | Last known counts and avatar | First run: empty controls |
| Page sheet open | In-page sheet shown | Bar dimmed, not tappable | None |
| Panel tap, page still loading | Bell or avatar | Nothing opens until the page is ready | None |

</frozen-after-approval>

## Code Map

- `app/views/shell/_top_bar.html.erb` -- always renders the bank counter, bell and phone menu in the app; `.bank-counter__count` targets and `[data-bell-target=count]` are already live, updated by streams and `reserve-chip`.
- `app/helpers/shell_helper.rb` -- `native_top_bar_data`; add `native_top_bar?` (UA lists `top-bar`, player present, not back office).
- `app/frontend/controllers/bridge/top_bar_controller.ts` -- reuse `navigate` and `refresh`; `.top-bar__end` is its element, so panel links already reach `openFromTopBar`.
- `app/frontend/controllers/bridge/screen_controller.ts` -- keeps sending `screen` labels. `bridge/back_controller.ts` and `_native_previous` go.
- `app/views/layouts/sheet.html.erb` -- sheets have no header and no bar padding.
- `script/pixel_art/app_icons.mjs` -- `iosVectorImage` reuses Android vectors; extend to bar icons from `app/frontend/images/pixel/`.
- iOS: `SceneDelegate.reloadTabs`, `TopBarNavigation` (layer becomes a child, not a modal), `GamebleWebViewController` (`viewWillAppear` fires on push, pop, cancelled swipe and tab change), `Bridge/BackComponent`.
- Android: `MainActivity`, `LayerActivity`, `GamebleActivity`, `GamebleWebFragment`, `ScreenTransition` (adds views to `R.id.screens`, so the bar sits outside it), `bridge/BackComponent`.

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/app_icons.mjs` -- generate bar icons (G, bell, arrow, both capsules) for both apps -- native rendering of the game's pixel art.
- [x] `app/helpers/shell_helper.rb`, `app/views/layouts/application.html.erb`, `_top_bar.html.erb` -- `data-native-bar` on `<html>`; counters and menu rendered on every screen; library status moved to the top of the page content; remove `_native_previous` -- one source of counts on every screen, collection progress kept.
- [x] `app/frontend/styles/native.css` -- header out of flow and invisible except open popovers, body padded by the bar height, sticky offsets under the bar; drop the old back rules -- content scrolls under a bar that overlays it.
- [x] `app/frontend/lib/native_top_bar.ts` + test, `events.ts`, `bridge/top_bar_controller.ts` -- read state (counts, bell, menu badge, avatar rasterized to PNG), report through the bridge on connect and on DOM change, open or close panels on `gameble:top-bar-panel`, close panels on `gameble:screen-shown` -- SVG cannot be drawn natively.
- [x] `mobile/ios/Gameble/TopBar/*`, `SceneDelegate`, `TopBarNavigation`, `GamebleWebViewController`, `Bridge/*`, `Gameble.swift` -- shell view controller holding tabs, layer and the one bar; state store persisted in UserDefaults; scroll via `contentOffset`; dim on sheet -- one instance above tabs and layer.
- [x] `mobile/android/.../TopBarView.kt`, `TopBarState.kt`, layouts, `MainActivity`, `LayerActivity`, `GamebleActivity`, `GamebleWebFragment`, `bridge/*` -- same behavior; `LayerActivity` keeps its own view bound to the shared state and opens with no activity animation -- an activity cannot share a view, and this looks still.
- [x] `test/system/native_app_test.rb`, `test/controllers/hotwire_native_test.rb`, `test/controllers/top_bars_controller_test.rb` -- UA with and without `top-bar`; padding; panels; reports -- covers the matrix's web half.
- [ ] Tag `ios-v1.2.0-8` once CI is green and staging is deployed -- the author's test build. Done by the orchestrator, not during implementation.

**Acceptance Criteria:**
- Given a sub-screen, when it opens, then "◀ previous" shows before its page has loaded.
- Given a screen with `top_bar_status`, when opened in the app, then the bar is identical to any other and the collection progress sits at the top of the page.
- Given the bell or avatar, when tapped, then the server-rendered panel opens right under the bar and its links follow "Leaving the current tab".
- Given a browser or an app without `top-bar`, when any page renders, then its bar is unchanged.

## Implementation Notes

- An app without `top-bar` loses `_native_previous` as the tasks ask: its sub-screens fall back to the web bar's own "◀ PONT" and `phone_back` links, and it keeps the edge swipe. Only earlier test builds are concerned.
- The bell's and the menu's panels were anchored to their buttons with `position-area`, which would have placed them at the collapsed header's corner where the browser supports it; `native.css` resets that for the bar.
- `.phone-menu` was `display: none` outside top-level screens, which would have kept its popover from showing; the bar's `native.css` displays it everywhere.
- `.rarity-counter` is no longer rendered under the bar, since its legend's id would repeat the one the progress brings to the page.
- Full-height page dialogs (trade picker, custom set editor) and the capsule zoom start under the bar. The bar dims, and returns if hidden, for any open `<dialog>` rather than only `bottom-sheet`: the page sends a `dialog` message, each screen stores it, and `showTabs` only hides the tabs.
- `isOnView` on iOS also excludes a tab under an open layer, whose view is still in the window.
- Real tokens used over the plan's estimates: sunken `#0E141B`, control border `#2A6F9A`.

## Plan Change Log

## Review Triage Log

Pass 1, quick lens: 10 findings kept and patched (high 2, medium 5, low 3), 2 rejected (low 1, false 1).

| Finding | Verdict | Route | Evidence |
|---------|---------|-------|----------|
| Android: hiding leaves a slice of the bar under the status bar | high | patch | `TopBarView.setShown` moves by `content.height` while the view is `inset + 56` tall with the inset as padding; no backdrop exists on Android |
| Both apps: restored scroll hides the bar with no player scroll | high | patch | `TopBarScroll.moved` acts on any offset change; no check for a drag on either platform |
| Android: taps on the bar's empty areas reach the page | medium | patch | Only four controls are clickable and the bar overlays the web view |
| iOS: dimmed bar passes taps through | medium | patch | `setDimmed` sets `isUserInteractionEnabled = false`, so hit-testing skips the bar |
| Cached pages report stale counts | medium | patch | `connect()` reports the DOM with `lastReport = null`, restored snapshots included |
| `.modal` dialogs do not dim the bar | medium | patch | Only `bottom_sheet_controller` sends `gameble:sheet-shown`, while 15 other `<dialog>` views exist; back can pop the screen under an open dialog |
| Controls expose fixed labels, counts lost to screen readers | medium | patch | Labels at `TopBarView.swift:165-183` and in `view_top_bar.xml`, never updated by `render` |
| Android: JavaScript evaluated on every step while hidden | low | patch | `setTopBarShown` sends the panel event before any state check, direct correction |
| System test reads the report count once | low | patch | `native_app_test.rb:158` asserts `sent + 1` while the bell frame may report; breaks the flaky-test rule |
| Comments beyond external constraints | low | patch | Listed by grep on the diff; AGENTS.md rule |
| Panel tap while a restore is running | low | rejected | The panel closes when the page is replaced, a rare tap in a short window, and a fix needs new state on both apps |
| App without `top-bar` loses `_native_previous` | false | rejected | The author accepted at the plan checkpoint that older builds keep the web bar but lose its back button, relying on the back gesture; the fix would edit this build's plan |

## Design Notes

The web view fills the space below the status bar and the bar overlays it; the page reserves the height with CSS. Hiding then only translates the bar, so the web view never resizes and scrolling does not jump. The avatar menu keeps today's unclaimed-achievements badge, shown on the avatar.

**Web header in the app.** `:root[data-native-bar] .top-bar` is `position:absolute; width:0; height:0; overflow:hidden; visibility:hidden`, and `.shell-popover` sets `visibility:visible`: popovers live in the top layer, so an ancestor's size and clip do not reach them, whereas `display:none` would. `.shell-popover` already sits at `--topbar-height + --space-3` from the top of the web view, which is right under the native bar. Check the capsule screen (`body:has(.booster[data-layout=phone])` is `height:100dvh`): padding must not make it scroll. Fix `feed-jump` (`top: --space-3`) and any other sticky that would slide under the bar.

**State report.** `bridge--top-bar` observes `.top-bar__end` (subtree, childList, characterData, attributes) and sends `state` `{ standard, special, bell, menuBadge, avatar }`, all display strings, coalesced to one message per task and skipped when unchanged. Sources: `.bank-counter__item:not(.bank-counter__item--special) .bank-counter__count`, `.bank-counter__item--special .bank-counter__count`, `[data-bell-target=count]` (empty when `hidden`), `#phone-menu-badge`, the avatar's `.player-chip__avatar` drawn on a canvas at 108px with smoothing off and exported as a PNG data URL, cached per source. Look at what `pixel_icon` emits (inline svg or img) to draw it. Native accepts a report only from the screen on view: iOS `view.window != nil`; Android the destination's navigator is `delegate.currentNavigator`. `gameble:screen-shown` keeps refreshing through `GET /top-bar`, and streams then trigger the observer; also report once after a refresh.

**Native to web.** A tap on the bell or avatar evaluates `window.dispatchEvent(new CustomEvent('gameble:top-bar-panel', { detail: { panel: 'bell' | 'menu' | null } }))` on the active web view: `bell` toggles `#bell-panel`, `menu` toggles `#phone-menu-panel`, `null` closes any open one. Same event with null when the bar hides. Declare it in `events.ts`. Light dismiss does not see taps on the native bar, hence the toggle. Capsule counter tap is native: route `/booster` through the existing `openFromTopBar` / `TopBarNavigation.open`.

**Gate.** `native_top_bar?` checks the user agent's `bridge-components` list for `top-bar`. Builds so far do not declare it, because that component was added after the last tag.

**Labels.** `BackComponent` drops `connect` and `back`, keeps `screen` and stores labels by location in a place the bar can read. The bar uppercases them. Fallback from `Gameble.text("Back", "Retour")`; Android from `strings.xml` or the same pattern as iOS, whichever `Gameble.kt` already uses.

**iOS.** New `ShellViewController` is the window root once signed in: tab controller as child filling it, the layer's navigator root as a child above it (slides up, withdraws on close), then a `statusBackdrop` (steam-bar colour, top to safe area top) above a `TopBarView` pinned to the safe area top, sliding under the backdrop via `transform`. `TopBarNavigation` holds a weak reference to the shell and loses `present`/`dismiss`. `isLayer` keeps working. `GamebleWebViewController.viewWillAppear` tells the shell, unless it is a native sheet, computing the left side from its index in `navigationController.viewControllers`; at index 0 of the layer, the label of the active tab's top screen. Scroll: KVO on `webView.scrollView.contentOffset` from `visitableDidActivateWebView`, removed on deactivate, acting only while `view.window != nil`; show under y 16, hide past +4, show past -4, ignore overscroll at either end. Bar height 56 plus the 2pt rule inside it. `showTabs(false)` from the sheet component also dims the bar. Sized for 360 wide: the back button's label compresses and truncates by tail, the right group keeps its size (content hugging and compression resistance). Add colours to `Palette`: steamBar `#171a21`, line `#2a475e`, raised `#1b2838`, sunken `#0d131b` (check the phone top bar's real control tokens in `app/frontend/styles`), text white, alert `#e8833a`. Touch targets at least 44.

**Android.** Wrap `R.id.screens` and `TopBarView` in a `FrameLayout` in both activity layouts; `ScreenTransition` and `TabSlide` keep animating `screens` only. `TopBarView` takes the status bar inset itself. `TopBarState` is an object with listeners, persisted in SharedPreferences, registered in activity `onStart`/`onStop`. `GamebleWebFragment.onStart` refreshes the left side when its navigator is the current one, using `navigator.isAtStartDestination()` and `navigator.previousLocation`; the tab listener does too. `LayerActivity` receives the previous label as an intent extra and uses `overridePendingTransition(0, 0)` on open and finish. Scroll: `setOnScrollChangeListener` in `onWebViewAttached`, same thresholds. `showTabs` dims too. Bar icons are generated vector drawables, fonts `R.font.jetbrains_mono_bold`.

**Icons.** `app_icons.mjs` writes `ic_bar_<name>.xml` from the pixel SVG runs (their `d` is valid `pathData`; a `fill="currentColor"` such as the arrow's becomes white) and imagesets `bar-<name>` via `iosVectorImage` with intent `original`. Its `colourRuns` is G-specific; generalise rather than copy. The pattern used by `iosVectorImage` needs the fill just before the path data.

## Verification

**Environment:** work only in the git worktree `/tmp/claude-1000/-home-teyermann-projets-gameble/109e551f-58e2-490a-b9d9-f7f0e3228431/scratchpad/hotwire-native`, branch `feature/hotwire-native`; the main checkout stays untouched. Run tests with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_merge` (Postgres already up; if a migration step complains the database is marked `development`, run `RAILS_ENV=test bin/rails db:environment:set`). No schema change is expected. No Mac here: Swift cannot be compiled locally, so read it twice; CI compiles it after the push. Kotlin compiles locally: `cd mobile/android && ./gradlew :app:assembleDebug` (Android SDK at `$ANDROID_HOME`, JDK 17) must pass. Do not install on or drive the phone: the orchestrator tests on the device afterwards. Restore `package-lock.json` with `git checkout -- package-lock.json` after npm commands. Never call `i18n-tasks normalize`. Do not run the whole system suite. Do not commit and do not push: leave the changes uncommitted, with no staged directories. Hotwire Native iOS source is at `/tmp/claude-1000/-home-teyermann-projets-gameble/109e551f-58e2-490a-b9d9-f7f0e3228431/scratchpad/hotwire-native/../hn-ios`, the Android AAR's classes at `/tmp/claude-1000/-home-teyermann-projets-gameble/109e551f-58e2-490a-b9d9-f7f0e3228431/scratchpad/hotwire-native/../aar`. Project rules: `/tmp/claude-1000/-home-teyermann-projets-gameble/109e551f-58e2-490a-b9d9-f7f0e3228431/scratchpad/hotwire-native/AGENTS.md`.

**Commands:**
- `bin/ci`, `npm run test:js`, `bin/rails zeitwerk:check` -- pass.
- `bin/rails test test/system/native_app_test.rb` -- pass.
- `node script/pixel_art/app_icons.mjs` twice -- no diff the second time.
- CI `iOS app`, `Android app`, `Android smoke test` -- success.

**Manual checks (if no CLI):**
- iPhone on TestFlight: every row of the matrix. Android when the phone is connected and a build requested.
