---
title: 'Shell and tokens'
type: 'feature'
ticket: '1'
created: '2026-10-05'
status: 'built'
baseline_revision: '3ba5bcf8289e6b5f6433f9190567c39b5cf0789c'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-gameble/ux-gameble/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The public card page (cards#show for a visitor, the share link) still shows the app chrome: back button and phone tab bar, where DESIGN.md asks for a slim top bar with the logo and the Steam image only and EXPERIENCE.md hides the tab bar.
    evidence: |-
      Quick review of story 8.1; app/views/layouts/application.html.erb renders shell/top_bar and shell/tab_bar for every non-back-office page. Pre-existing (the medieval shell also wrapped it); the public card page belongs to epic-space-terminal-screens.
    location: >-
      app/views/cards/show.html.erb
    severity: medium
  - summary: >-
      The card page keeps a game-styled text button posting to /auth/steam, while DESIGN.md makes Valve's official image the only link to Steam's sign-in (the sign-in panel of story 8.2 replaces such calls to action).
    evidence: |-
      Quick review of story 8.1; app/views/cards/show.html.erb:18 predates this story. The attic's two such buttons are 8.2's hub rework.
    location: >-
      app/views/cards/show.html.erb:18
    severity: low
  - summary: >-
      The top bar reads Game::BankSummary on every signed-in page, whose bonus_collectable part (published-season lookup and daily-claim check) the packs chip never uses: up to two wasted queries per page.
    evidence: |-
      Quick review of story 8.1; app/helpers/shell_helper.rb shell_bank. The hub's duplicate read was patched (reuses @bank); dropping the bonus part needs a parameter or a narrower query.
    location: >-
      app/helpers/shell_helper.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Every page still wears the medieval shell (Jost, parchment and brass tokens, the status band, flash paragraphs, text plates), which contradicts DESIGN.md, EXPERIENCE.md and AD-16/AD-27/AD-28; every later screen of the redesign needs the new shell first.

**Approach:** Replace the shell once (AD-28): DESIGN.md tokens as custom properties, self-hosted pixel fonts, a layout with top bar, phone tab bar, permanent atmosphere layers, toast region, view-transition and viewport metas, new Button/Panel/Toast/SteamSignIn components and a script exporting pixel icons; existing screens keep their content, recoloured to the new tokens. The back-office gets the tokens without atmosphere or tab bar.

## Boundaries & Constraints

**Always:**
- DESIGN.md and EXPERIENCE.md win over mocks; mocks (`ux-gameble/mockups/*.html`) are look/timing references only, never copied code.
- Tokens: exact DESIGN.md frontmatter values; names `--color-*`, `--space-*`, `--font-*` (architecture conventions), other component tokens named after their DESIGN key (`--pixel-outline-4`, `--panel-border`, `--control-border`, `--focus-ring-*`, `--ease-out`, `--topbar-height`, …). Text sizes in rem (16px root); art pixel stays px.
- No `style` attribute in server HTML (AD-16); dynamic values via custom properties set by a controller. Stimulus controllers remove listeners/timers on disconnect.
- Every focusable element shows the DESIGN focus ring (3px `--color-text-max` outline, 3px `--color-outline` gap), never gold.
- Copy: all new strings in `config/locales/fr.yml` and `en.yml` (both), "vous", terminal labels in natural case uppercased by CSS, no "Confrère"/title; glyphs ◀ ▶ ▸ ✕ ✓ ◆ ⇄ ↗ ⧗ are pixel SVG icons, never typed characters.
- Reduced motion: `prefers-reduced-motion: reduce` or `html[data-motion=reduced]` stops star shift, view-transition slides and toast rise (one shared switch in `app/frontend/lib/motion.ts`).
- Atmosphere layers (`data-turbo-permanent`, `aria-hidden`) sit under all content, bars, toasts and dialogs; never in the back-office.

**Never:**
- Do not rework the attic/hub content, its copy, `SampleIsland`, the card face, `Card.tsx`, the reveal, tier code names (`steel`…`gold`) or `dust_tier` (stories 8.2, 8.3, 8.6, 8.11). Recolouring their CSS to new tokens is required; restructuring is not.
- No CSP changes (8.4), no Google Fonts or CDN, no feature flag or second stylesheet, no landscape layout, no scaling.
- Never push or deploy.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Visitor, hub | GET `/fr` signed out | Top bar: logo + "GAMEBLE", official `sits_01.png` image as the submit button of a POST `/auth/steam` form with `origin`=current path, `data-turbo=false` | — |
| Player, other page | GET `/en/library` signed in | Top bar: back button (◀ icon + "Pont" → `home_path`), rarity counter (5 tier icons + copies owned in the published season), packs chip (count, "boosters", "+1 in" countdown or "Reserve full" at `Game::Pack::BANK_SIZE`), player chip opening a popover menu (own public profile, back-office for staff, sign out) | No published season: counter shows zeros |
| Flash | redirect with `notice`/`alert` | Rendered as toasts in a polite live region (no `.flash`); ✕ closes; auto-dismiss after ≥5s + 1s per 10 words, paused on hover/focus | Without JS the toast simply stays |
| `gameble:toast` event | `window.dispatchEvent(new CustomEvent("gameble:toast", {detail}))` | Toast appended from the server-rendered template | Unknown fields ignored |
| Phone | viewport 360×740 / 390×844 | Tab bar fixed bottom (PONT, BOOSTER, COLLECTION, ÉCHANGES, PLUS) with safe-area padding; rarity counter hidden from top bar; no horizontal page scroll | Tabs whose screen does not exist yet (BOOSTER, ÉCHANGES, PLUS) render disabled (`aria-disabled`, not links) |
| Back-office | GET `/fr/back-office` as staff | New tokens, top bar with "◀ Pont", no atmosphere layers, no tab bar | — |

</intent-contract>

## Code Map

- `app/views/layouts/application.html.erb` -- the only HTML layout (back-office included). Replace status band + `.flash` block. `content_for(:back_button)` is set by every non-home view: keep it as the logo/back switch. Keep `csp_meta_tag`, vite tags, `yield :head`.
- `app/frontend/entrypoints/application.css` -- imports styles; holds old base, button, flash, ledger, card-preview, pack-result rules. `app/frontend/styles/{tokens,fonts,attic,library,card-detail,card,reveal}.css` -- old token names (`--color-ink`, `--color-surface`, brass/leather/dust, `--color-rarity-steel…amethyst`, `--shadow-hard`, `--plate-padding-*`, Jost families).
- `app/frontend/fonts/jost-*.woff2`, `app/frontend/fonts/OFL.txt` -- Jost, to delete.
- Font sources (already downloaded, OFL): `/tmp/claude-1000/-home-teyermann-projets-gameble/ac0c8a69-3fc0-4860-bec0-befb1623ac64/scratchpad/fonts/fontsource-{pixelify-sans,silkscreen,vt323}-5.3.0/package/` -- `files/*-latin-{400,600,700}-normal.woff2`, `files/*-latin-ext-*-normal.woff2`, `LICENSE` (OFL text), `latin*.css` (unicode-ranges).
- `_bmad-output/initiative-gameble/ux-gameble/imports/sits_01.png` -- Valve's official image, copy unmodified.
- `app/components/button_component.rb/.html.erb` (+ `test/components/button_component_test.rb`) -- variants primary/secondary; form/link/button modes; extend.
- `app/components/text_plate_component.*` (+ test) -- delete; 16 call sites in `app/views/**` and `app/frontend/components/RevealErrorBoundary.tsx` (`className="text-plate"`).
- `app/frontend/controllers/countdown_controller.ts` -- reused by the packs chip; add a `refresh` Boolean value (default true) so the chip never refreshes the page.
- `app/frontend/entrypoints/application.ts` -- registers controllers by glob; nothing to change for new controllers.
- `packs/game/app/queries/game/{bank_summary,collection_summary}.rb` -- query patterns; `Game::Pack::BANK_SIZE`; `Catalog::PublishedSeason.call`; `Catalog::Rarity::TIERS` (1..5 → steel…gold); tier names at `catalog.rarity.<code>`.
- `script/card_art/generate.mjs` -- precedent for a deterministic Node generator writing SVGs; vite-plugin-ruby already exposes `app/frontend/{fonts,images}/**` to `vite_asset_path`.
- Tests asserting the old shell: `test/controllers/{pages,sessions,authorization,card_preview_tags,library,library_set,public_profiles,cards,packs}_controller_test.rb` (and `authorization_test.rb`), `test/controllers/back_office/{dashboard,seasons,import_runs}_controller_test.rb`, `test/system/attic_test.rb` (`.status-band`, `.flash`, `.text-plate`, "Back to the attic", title).

## Tasks & Acceptance

**Execution:**
- [x] `script/pixel_art/export.mjs` -- new deterministic generator: icons defined as character grids (legend: `.` transparent, `c` currentColor, fixed hex otherwise), written as `app/frontend/images/pixel/<name>.svg` with viewBox in art pixels, width/height at 2 CSS px per art pixel, `shape-rendering="crispEdges"`, merged row runs per colour; `--check` exits 1 when a file differs. Set: `logo` (12×12), `rarity-1`…`rarity-5` (7×7 with `-hi`/`-lo` edges: disc, double ring, diamond, triangle, star), `arrow-left`, `arrow-right`, `arrow-small-right`, `close`, `check`, `diamond`, `swap`, `external`, `hourglass`, `canister-small` (8×11), `avatar-default` (16×16), `tab-hub`, `tab-booster`, `tab-collection`, `tab-trades`, `tab-more`, and `starfield` (a seeded tile of 2px and 4px `--color-star` squares in CSS px). Run it and commit the outputs.
- [x] `app/frontend/fonts/` -- delete Jost files and `OFL.txt`; add the latin and latin-ext woff2 of Pixelify Sans 600 and 700, Silkscreen 400, VT323 400, and `OFL-PixelifySans.txt`, `OFL-Silkscreen.txt`, `OFL-VT323.txt`.
- [x] `app/frontend/styles/fonts.css` -- `@font-face` per file with fontsource's unicode-ranges, `font-display: block`.
- [x] `app/frontend/styles/tokens.css` -- rewrite: every DESIGN.md colour, typography style (`--font-<style>` shorthand + `--tracking-<style>`), spacing/size, component css values (outlines, borders, bevel, focus ring, scanlines, vignette desktop/phone, hazard, motion easings). Remove every old token.
- [x] `app/frontend/styles/shell.css` (new, imported by the entrypoint) -- base (`body` ground + VT323 body, `html` scroll-padding for the phone tab bar, focus ring, h1/h2 in Pixelify), top bar, tab bar (<720px only, fixed, safe-area), atmosphere layers, toast region (bottom centre desktop, top phone, 250ms rise), buttons, panels (quiet, corner brackets), layout widths (content ≤1280px, phone column ≤480px, gutters, breakpoints 720/900/1180), view-transition rules (old slides 32px + fade 170ms, new from 48px 260ms after 40ms; none when reduced), back-office variant (`body.is-back-office`). Move/replace the shell rules out of `application.css`; restyle ledger/card-preview/pack-result with new tokens.
- [x] `app/frontend/styles/{attic,library,card-detail,card,reveal}.css` -- recolour only: map old tokens to new (bg→ground, surface→panel, surface-sunken→panel-sunken, ink→text for text / line or outline for borders, ink-muted→muted, danger→alert, success→lime, brass/leather/dust/attic locals→line/panel/dim tones, rarity steel/emerald/sapphire/amethyst/gold→commune/peu-commune/rare/epique/legendaire with light→hi, dark→lo, `--shadow-hard`→pixel outline, plate padding→panel padding, Jost families→pixel font tokens). Fix the Jost comment in `card.css` and `config/locales/fr.yml`.
- [x] `app/components/button_component.rb/.html.erb` -- variants `primary`, `secondary` (default stays primary for compatibility), `danger`, `link`; `size: :small`; `icon:` (leading pixel icon); `disabled: true` renders `<button type=button disabled>`. CSS per DESIGN Buttons (lift 3px on hover, press 2px with inset moved to top, disabled no lift).
- [x] `app/components/panel_component.rb/.html.erb` -- `PanelComponent.new(tag: :div, quiet: false, brackets: false)` → `.panel`, `.panel--quiet`, `.panel--brackets`. Replace every `TextPlateComponent` call and `RevealErrorBoundary`'s class; delete `TextPlateComponent` and its test.
- [x] `app/components/toast_component.rb/.html.erb` -- `ToastComponent.new(message:, title: nil, tone: :notice|:alert)`: steady light (accent/orange), optional Silkscreen title, VT323 line, ✕ button (accessible name "Fermer"/"Close"), `data-turbo-temporary`.
- [x] `app/components/steam_sign_in_component.rb/.html.erb` -- one-button POST form to `/auth/steam` (`origin` param, `data-turbo=false`) whose button holds `sits_01.png` (copied to `app/frontend/images/steam/sits_01.png`) at 180×35 in a ≥44px hit area; alt says it signs in through Steam and opens Steam.
- [x] `app/helpers/shell_helper.rb` -- `pixel_icon(name, **attrs)` inlines `app/frontend/images/pixel/<name>.svg` (cached, `aria-hidden="true"`, `focusable="false"`, raises on unknown names); `back_office_page?`; memoized per request `shell_bank` (`Game::BankSummary`) and `shell_tier_counts` for `current_player`.
- [x] `packs/game/app/queries/game/tier_counts.rb` -- `Game::TierCounts.call(player)` → `{1=>n,…,5=>n}` copies held per tier in the published season, one query, zeros for nil/no season.
- [x] `app/views/shell/_top_bar.html.erb`, `_tab_bar.html.erb`, `_atmosphere.html.erb`, `_toasts.html.erb` + `app/views/layouts/application.html.erb` -- layout per the I/O matrix; meta `viewport` with `viewport-fit=cover`, `theme-color` `#171a21`, `<meta name="view-transition" content="same-origin">`; preload the four latin woff2 (`crossorigin`); title "gameble"; optional `content_for(:screen_title)` and `content_for(:ticker)` slots; `<main>` keeps `id="main"`. Rarity counter and player menu use native `popover`/`popovertarget` (legend "Raretés": icon, name from `catalog.rarity.<code>`, count). Packs chip is not a link yet (no booster screen).
- [x] `app/frontend/lib/events.ts` -- the typed `gameble:*` event map (only `gameble:toast` now) with `dispatchGameble`/`onGameble` helpers. `app/frontend/lib/motion.ts` -- `motionReduced()`. `app/frontend/lib/toast.ts` -- pure `toastDuration(text)` (5000 + 1000 per started 10 words) + `app/frontend/lib/toast.test.ts`.
- [x] `app/frontend/controllers/toast_controller.ts` -- on the region: timers per toast, pause on hover/focus, ✕ closes, listens to `gameble:toast` and clones the template. `app/frontend/controllers/starfield_controller.ts` -- shifts the star layer sideways (transform, 1.1s) on each `turbo:load` after the first, wrap without visible jump, nothing when reduced.
- [x] `config/locales/fr.yml`, `en.yml` -- new `shell.*` keys (top bar, back, rarity counter + legend, packs chip incl. full reserve, player menu, tab labels, toast close, Steam image alt, theme); drop `layouts.application.status_band`; title "gameble".
- [x] Tests -- component tests (Button variants/size/icon/disabled, Panel, Toast, SteamSignIn), `test/helpers/shell_helper_test.rb`, `test/packs/game/tier_counts_test.rb` (beside `collection_summary_test.rb`), `test/integration/shell_test.rb` (each I/O row via `assert_select`, metas, preloads, atmosphere `data-turbo-permanent`, toasts replace flash), a test running `node script/pixel_art/export.mjs --check`, `test/system/shell_test.rb` (desktop 1400 and phones 390×844 / 360×740: top bar, tab bar visibility, no horizontal scroll, toast ✕ closes, fonts loaded via `document.fonts.check`, screenshots); update every listed old-shell assertion.

**Acceptance Criteria:**
- Given any page, when rendered, then no `Jost`, no parchment colour (`#f4ead2`, `#e9dcc0`, `#e2d1ad`), no `text-plate`/`TextPlateComponent`, no `status-band` and no `.flash` remain in `app/`, `config/` or `test/`.
- Given a desktop and a phone viewport, when visiting the hub, library, a card page, a pack page and the back-office, then each renders inside the new shell and the screenshots show dark tokens and pixel fonts.
- Given the export script, when run twice, then no file changes and `--check` passes.
- Given all checks of the verification list, when run, then they pass.

## Implementation Notes

- Shell queries: a signed-in page now runs four or five more queries (`Game::BankSummary`'s count, next pack, published season when not already cached, daily claim; `Game::TierCounts`' one). The request-count tests were raised accordingly (library 6→10, library set 9→13, public profile +4, card 4→9).
- Button labels are uppercased by CSS (`.button`, top bar, tab bar, toasts' titles, legend): system tests reading rendered text (`pack_reveal_test`, `card_detail_test`) compare the uppercased text.
- System tests sign in and out through shared helpers in `ApplicationSystemTestCase` (`click_steam_sign_in`, `assert_signed_in`, `sign_out`, `assert_signed_out`); the old status band's "Back to the attic" clicks became "Bridge".
- The player menu links the player's own public profile (with their token): `cards_controller_test`'s "no token in the page" check is scoped to `head` and `main`.
- Card art: the generated `app/frontend/images/card/*.svg` held two parchment pixels (`#e2d1ad` medallion, `#f4ead2` season seal); they were recoloured in place to `#c7d5e0` / `#e6eef5`, and `script/card_art/generate.mjs` maps them the same way (`RECOLOUR`). That generator cannot run today: its sources (`mockups/card-backs.html`, `card-face.html`) are gone.
- Spacing scale: old `--space-6` (24px) and `--space-7` (32px) were remapped to the new `--space-7` / `--space-8` in the recoloured screens, so their layout keeps its sizes. Old label/plate paddings map to `--space-2 --space-4` (same 4px 12px).
- Added `--font-weight-regular/semibold/bold` and `--font-family-pixelify/silkscreen/vt323` token helpers next to the `--font-<style>` shorthands; `--overlay-shadow` holds DESIGN's "one soft drop shadow" for toasts and popovers (DESIGN gives no value).
- English back label is "Bridge" (EN copy unwritten; "Pont de commandement" = command bridge). No `shell.theme` key was added: no string needs it.
- Tab labels use letter-spacing 0 (as the phone mock) so "COLLECTION" fits a 72px tab at 360px.

## Plan Change Log

## Review Triage Log

### 2026-10-05 — Review pass
- verdicts: 8 findings — high 0, medium 3, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Same-page visits (hub countdown morph refresh and its retries, daily bonus redirect, tapping the current tab) slide `main` and shift the stars — confirmed in Turbo 8.0.23 (`renderPageSnapshot` transitions whenever both snapshots carry the meta; `turbo:visit` fires on refreshes). Fixed: the starfield controller sets `html[data-screen-change=same]` on a same-path visit and skips the shift; CSS drops the screen animation under it; system test added.
  - `[medium]` `[patch]` A morph refresh removes toasts still on screen, and a toast brought by the morph (the daily bonus "collected" notice, `daily_bonuses_controller.rb:14`) got no timer — confirmed: the region is not permanent and Turbo's morph callbacks only spare permanent nodes. Fixed: the region cancels `turbo:before-morph-element` for tracked toasts, adds the incoming toast after the morph, and times any toast target that connects; system tests for both.
  - `[low]` `[patch]` `Game::BankSummary` runs twice on the hub and its bonus queries are unused by the chip — the hub duplicate fixed (`shell_bank` reuses `@bank`); the unused bonus part deferred (needs a parameter or a narrower query).
  - `[medium]` `[defer]` The public card page keeps the app chrome (back button, tab bar) instead of DESIGN.md's slim bar — pre-existing (the old shell wrapped it too) and owned by epic-space-terminal-screens; recorded in deferred-work.md.
  - `[low]` `[defer]` A game-styled sign-in button remains on the card page — pre-existing (`cards/show.html.erb:18`), replaced by story 8.2's sign-in panel; recorded in deferred-work.md.
  - `[low]` `[patch]` Reduced motion still lets buttons lift and press (translate) — fixed: `transform: none` on `.button:hover` and `:active` in both reduced-motion blocks.
  - `[low]` `[patch]` Toasts ignore Esc, and closing a focused toast drops focus to the body — Esc on a focused toast now closes it (system test added); the focus drop is rejected as a low with a rare path (a toast is seldom focused) whose fix adds a focus-destination rule the shell does not define yet.
  - `[low]` `[patch]` The `RECOLOUR` constant sat between `pixelSvg`'s doc comment and the function — moved above the comment.

### 2026-10-06 — Review pass
- verdicts: 7 findings — high 0, medium 3, low 3, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` Back and Forward count as same-page visits. On a restoration, Turbo 8.0.23's `History.onPopState` sets the location to the entry before `turbo:visit` fires, so the requested path always equals `location.pathname`. The restored screen lost its slide and the stars stayed still, and the marker lingered until the next link visit. Fixed: `starfield_controller.ts` treats `action: "restore"` as a screen change. New system test "Back and Forward are screen changes" (marker cleared, `.main` captured as `screen`, stars −160 → −320 px); it fails without the fix.
  - `[low]` `[reject]` The marker is decided from the requested URL, not the rendered page. A redirected GET (a visitor tapping COLLECTION and being sent back to the hub) slides the hub over itself. Real, but only on visitor-only redirect paths, and the cost is one 300ms slide. A fix has to read Turbo's fetch response (`turbo:before-fetch-response`) or the followed redirect visit, which adds a new branch, so it is not worth it now.
  - `[low]` `[patch]` The same-path branch never reset `pending`, so a different-path visit superseded by a same-path one (tapping the current tab while a link loads, or the hub countdown's refresh during a link visit) shifted the stars on a same-page render. Fixed: the same-path branch sets `pending = false`.
  - `[medium]` `[patch]` Under `html[data-screen-change=same]`, only the screen's old and new images lost their animation. `::view-transition-group(screen)` kept its UA 250ms animation, so the opaque old picture showed under the new one, for example the daily booster panel after "Collect" or the counts after the countdown refresh. Fixed: under the marker `.main` gets `view-transition-name: none`, so the root's new picture replaces the old one at once. The existing refresh test now asserts the computed name (`none` after a refresh, `screen` after a link visit).
  - `[medium]` `[patch]` During a screen change the sliding screen painted over the phone tab bar and the toasts, which were part of the root snapshot under `group(screen)`. EXPERIENCE.md says the bars do not move. Fixed: `.tab-bar` and `.toasts` get their own `view-transition-name`. Their group and new image have no animation and their old image is hidden, so they stay above the screen and change at once. System test asserts both names on a 390px phone.
  - `[low]` `[reject]` Several flash toasts in one morph refresh can come out in reverse order: with one kept toast A, notice B1 soft-matches A and is re-added in a microtask, while alert B2 is inserted at once (A, B2, B1). It needs a morph that brings both a notice and an alert while a toast is still shown, which is rare, and fixing the order means new insertion bookkeeping. The lens confirmed that no toast is lost or duplicated for 1+1, 2+1, 1+2 and 2+2. Two new system tests cover several kept toasts (order kept) and two kept toasts plus the incoming daily-bonus notice (three shown, all timed out).
  - `[false]` `[reject]` Leaving the back-office with a stale marker. Entering it always clears the marker, because the starfield controller is still connected when that `turbo:visit` fires. Nothing in the back-office sets the marker, and `.is-back-office .main` has no transition name. The `pending` shift kept for the next page with stars is a real screen change, as intended. New system test: hub refresh, then back-office, then Bridge; the marker is gone each time and the view-transition names are right.

## Auto Run Result

- **Summary:** the medieval shell is replaced on every page: DESIGN.md tokens (`tokens.css`), self-hosted Pixelify Sans 600/700, Silkscreen 400 and VT323 400 (latin + latin-ext woff2, OFL texts, latin files preloaded), a layout with top bar (logo or "◀ Pont", rarity counter with its "Raretés" legend, packs chip, player chip with a transitional menu, or Valve's official Steam image), phone tab bar, permanent star field/scanlines/vignette, toasts replacing flash, view-transition and viewport metas; Button (danger, link, small, icon, disabled), Panel, Toast and SteamSignIn components; `TextPlateComponent` removed; a deterministic `script/pixel_art/export.mjs` writing 23 pixel SVGs; existing screens recoloured only; the back-office keeps tokens and top bar without atmosphere or tab bar.
- **Files:** `app/frontend/styles/{tokens,fonts,shell}.css` (tokens, fonts, shell rules), `app/frontend/styles/{attic,library,card-detail,card,reveal}.css` and `entrypoints/application.css` (recoloured), `app/frontend/fonts/*` (new fonts, Jost removed), `app/frontend/images/pixel/*` and `images/steam/sits_01.png` (exported icons, official image), `app/frontend/images/card/*.svg` + `script/card_art/generate.mjs` (two parchment pixels recoloured), `app/components/{button,panel,toast,steam_sign_in}_component.*`, `app/helpers/shell_helper.rb`, `app/views/shell/*` and `layouts/application.html.erb` (the shell), `packs/game/app/queries/game/tier_counts.rb` (rarity counter), `app/frontend/{lib/events,lib/motion,lib/toast}.ts`, `controllers/{toast,starfield,countdown}_controller.ts`, `config/locales/{fr,en}.yml` (`shell.*`), views switched from TextPlate to Panel, tests (new component, helper, query, integration, export-check and system tests; old-shell assertions updated).
- **Review:** quick lens, 8 findings: 6 patched (2 medium, 4 low), 2 deferred (public card page chrome, card page sign-in button) plus the unused bonus queries of the top bar deferred; rejected: the focus drop after closing a focused toast (rare path, fix needs an undefined focus rule).
- **Follow-up review:** recommended (`true`) — two medium findings were patched on this first pass. The specific unverified risk: the toast region's new morph handling (cancelling `turbo:before-morph-element`, re-adding the incoming toast in a microtask) and the same-path screen-change flag are covered only by hub system tests; several toasts during one morph, and leaving the back-office (no starfield controller there to clear the flag), are untested.
- **Verification:** `node script/pixel_art/export.mjs --check` ok (23 files); `bin/rubocop` no offenses; `packwerk validate` and `check` clean; `i18n-tasks missing` none; `npm run typecheck` clean; `npm run test:js` 63 passed; `bin/rails test` 1055 runs, 0 failures; `bin/rails test:system` 58 runs, 0 failures (after the review patches). Acceptance grep (Jost, parchment hexes, text-plate, status-band, `.flash`) empty in `app/`, `config/`, `test/`.
- **Residual risks:** signed-in pages run 4–5 more queries (request-count tests raised); button labels uppercased by CSS; the transitional player menu, disabled tabs, non-refreshing chip countdown and always-rendered view-transition meta are recorded in deferred-work.md; screen-reader announcement of toasts present at load is untested.

### Follow-up pass (2026-10-06)

- **Summary:** follow-up quick review of the shell. It found and fixed Back/Forward being taken for same-page visits, a stale pending star shift, the double picture on same-page refreshes, and the tab bar and toasts being covered by the sliding screen. It also added system tests for the open risks of the first pass: a refresh outside the hub, history navigation, leaving the back-office, and several toasts across a morph refresh.
- **Files:**
  - `app/frontend/controllers/starfield_controller.ts`: a restoration is a screen change; a same-path visit drops a pending shift.
  - `app/frontend/styles/shell.css`: under the marker `.main` is not captured; the tab bar and the toasts are captured on their own, without animation.
  - `test/system/shell_test.rb`: five new tests, and the refresh test extended.
- **Review:** quick lens, 7 findings.
  - Patched 4: medium 3, low 1.
  - Deferred: none.
  - Rejected 3:
    - The redirected-GET marker: low, visitor-only, the fix needs a new branch on the fetch response.
    - Reverse order of several toasts in one morph: low, rare, the fix needs insertion bookkeeping.
    - Stale marker after the back-office: false, the marker is cleared on entry.
- **Follow-up review:** not recommended (`false`): this follow-up pass patched no high finding.
- **Verification:**
  - `node script/pixel_art/export.mjs --check`: ok.
  - `bin/rubocop`: no offenses.
  - `packwerk validate` / `check`: clean.
  - `i18n-tasks missing`: none.
  - `npm run typecheck`: clean.
  - `npm run test:js`: 114 passed.
  - `bin/rails test`: 1130 runs, 0 failures.
  - `bin/rails test:system`: 71 runs, 0 failures.
  - The new shell tests fail without the patches (3 failures) and pass with them.
- **Residual risks:**
  - The view-transition pseudo-elements are checked only through computed `view-transition-name` values, not by watching a running transition.
  - Redirected GETs still decide the marker from the requested URL.

## Design Notes

- Transitional choices, record each in `_bmad-output/initiative-gameble/deferred-work.md`: the player chip opens a popover menu (public profile, back-office, sign out) until Profil et paramètres exists; BOOSTER/ÉCHANGES/PLUS tabs are disabled and the packs chip is not a link until their screens ship; the chip's countdown does not refresh the page; the view-transition meta is always rendered (no stored "Animations réduites" yet), CSS removes the animation under reduced motion.
- Icon SVG shape (example):
  ```svg
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 7 7" width="14" height="14" shape-rendering="crispEdges"><path fill="#66c0f4" d="M3 0h1v1h-1z…"/></svg>
  ```

## Verification

**Commands:**
- `node script/pixel_art/export.mjs --check` -- exit 0
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test && bin/rails test:system` -- pass

**Manual checks (if no CLI):**
- View the system-test screenshots (desktop, 390, 360, back-office): dark ground, top bar, tab bar on phone only, toasts, Pixelify/Silkscreen/VT323 visible.
