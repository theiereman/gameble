---
title: "Reviewer Gate: technical feasibility"
lens: technical-feasibility
reviewed: 2026-10-05
inputs:
  - DESIGN.md (draft, 2026-10-05)
  - EXPERIENCE.md (draft, 2026-10-05)
  - mockups/key-screens.html, mockups/mobile.html (approved prototypes, code searched)
  - .memlog.md (2026-10-05 entries)
  - ../architecture-gameble/architecture-gameble.md (final, 2026-10-02)
  - ../spec-gameble/spec-gameble.md (+ companions; the `stack.md` the architecture cites does not exist)
  - app code on branch ux-redesign (epic 1: layout shell, attic, back-office shell)
---

# Technical feasibility review

## Verdict

**Conditional pass: buildable, but not yet without guessing.** The look and motion can be built on the recorded stack (Rails + ViewComponent + Hotwire, two React islands through Turbo Mount, plain CSS tokens). Nothing in the spines needs a stack change. The Steam CDN sends `Access-Control-Allow-Origin: *` on every host tested, so the in-browser pixel filter works as designed.

Before the first story starts, two things must be settled:

1. **Where each cover image comes from.** The mocks build the old unhashed CDN path. For recent games that path is missing, or worse, serves a grey placeholder with a 200 status.
2. **The fluid layout rules.** The mocks are absolutely positioned 1280 × 720 and 390 × 844 stages, so there is no CSS to port. The breakpoints and short-viewport rules are still marked "open".

Five more high findings are decisions the architecture must take (filter off the main thread, the opening protocol, island scope and the contract between components, Turbo navigation motion, server mechanisms not yet in the architecture). The medium and low findings are spine fixes or build rules.

| Severity | Count |
|---|---|
| Critical | 2 |
| High | 5 |
| Medium | 12 |
| Low | 12 |

**Evidence gathered for this review (2026-10-05):**
- `curl` with an `Origin` header against the Steam CDN. Results:
  - `cdn.akamai.steamstatic.com`, `cdn.cloudflare.steamstatic.com`, `shared.akamai.steamstatic.com`, `shared.fastly.steamstatic.com`, `steamcdn-a.akamaihd.net` and `avatars.(akamai.)steamstatic.com` all answer `Access-Control-Allow-Origin: *` on 200s.
  - 404s carry no ACAO header.
  - `OPTIONS` preflight answers **405**.
  - `Cache-Control: public` runs from 4 days to 10 years.
- A Node benchmark of the mocks' `medianCut` + `quantize`, using noisy worst-case pixels.
- `fc-query` glyph coverage of the three Google Fonts files.

## Findings

### Critical

**C1. The cover URL is built from the old path; recent games get no art or silently get a grey placeholder.**
- *Location:* DESIGN.md › Pixel filter (`source: Steam vertical library image (600 x 900)`); mocks `CDN='https://cdn.akamai.steamstatic.com/steam/apps/'` + `id+'/library_600x900.jpg'` (key-screens.html l.1064, l.1256).
- *Risk:* For apps whose assets moved to hashed paths, the legacy path fails in two ways:
  - It returns 404: PEAK, 3527290. The card then shows "IMAGE INDISPONIBLE" although Steam has an image.
  - It returns **200 with a 300 × 450 single-channel grey JPEG**: Battlefield 6, 2807960. `loadImg` accepts it (`naturalWidth > 0`) and the card shows flat grey art, a silent failure.

  The hashed URLs from `IStoreBrowseService/GetItems` (`assets.asset_url_format` + `library_capsule_2x`, e.g. `…/2807960/289b1c…/library_capsule_2x.jpg`, 600 × 900, ACAO `*`) work. Recent, popular games, the most desirable cards, are the ones affected.
- *Recommendation (architecture + import):*
  - The `Steam` import stores the full vertical-capsule URL per card: hashed `library_capsule_2x`, with `library_capsule` as a fallback.
  - CAP-2's "games without a vertical Steam image are excluded" is tested against the API's asset list, not against the legacy path.
  - `Catalog` exposes an opaque `image_url`, so AD-4 stays intact.
  - The filter package treats a decoded image smaller than 300 × 450 or with a single channel as missing.
  - A periodic import refreshes asset URLs, because a hashed path goes stale when the developer replaces the art.
  - DESIGN.md says "the vertical capsule URL recorded at import" instead of naming a size and path.

**C2. The fluid desktop and the phone layout cannot be coded without guessing.**
- *Location:*
  - DESIGN.md › Layout & Spacing: "Open: the maximum width value, the breakpoint to the phone layout, and tablets", plus the `[ASSUMPTION]` column widths and reflow.
  - EXPERIENCE.md › Responsive & Platform.
  - Mocks: every block is `position:absolute` with pixel `left/top`, e.g. `.b-stage{left:364px;top:72px;width:884px;height:600px}`, `.bk-grid{left:276px;top:64px}`. `fit()` scales the whole stage. The phone mock switches at `innerWidth <= 500`.
- *Risk:* There is no layout to port, only a picture of one. Undecided cases:
  - **Short desktop viewports.** 1366 × 768 laptops give about 650px of content. The hub's centre (card-xl 360 + pedestal + title + button) and the booster stage (600px tall) do not fit. Nothing says what scrolls or what compacts.
  - **Medium widths.** Hub: left column 320 + showcase with 520px rays + right column 320 + gutters is about 1150px or more before "the right column moves under the centre". Booster: the 5 × card-m deal row (about 900px) beside the 320px info column needs about 1300px.
  - **Phone in landscape.** At 844 × 390 the width is over 500, so the phone would get the desktop layout with 390px of height.
  - **Tablets.**
- *Recommendation (spine fix, before the layout-shell story):* Write concrete rules into DESIGN.md:
  - Phone layout when `(max-width: 719px)`, or when `(pointer: coarse) and (max-height: 500px)`.
  - Two-column desktop from 720 to 1179px: the right column goes under the centre, and the booster info column goes above the stage.
  - Three columns from 1180px. Maximum content width of 1440px.
  - Top bar and ticker fixed. The central area scrolls when the height is short.
  - The **booster stage is a fixed logical stage** (884 × 600), centred and scaled down only by an integer-friendly factor (as the mocks' `fit()` does), with a minimum height. Its choreography uses stage coordinates, not layout.
  - Phone landscape shows the phone layout with the booster asking to rotate, or a compact `card-m` deal; pick one.
  - Tablets follow the width rules: no third layout.

### High

**H1. Main-thread cost of the pixel filter, worst during the opening.**
- *Location:* DESIGN.md › Pixel filter steps 1–4; AD-17; mocks `getArt` / `medianCut` / `quantize` run synchronously on the main thread, one palette per size (`ARTP` key `id:w×h`).
- *Risk:*
  - Measured in Node on a desktop CPU with noisy worst-case pixels: about 2.5 ms (card-s, 50 × 51), 5 ms (m), 9 ms (l) and 12 ms (xl) per image for quantisation alone.
  - On top of that comes the 600 × 900 JPEG decode (about 2 MB RGBA) and the halving downscale with `getImageData` read-back.
  - A low-end Android is 5 to 10 times slower, so roughly 20–120 ms per image.
  - The booster deals five cards whose images load and filter **during the 1.2 s explosion**. That is up to about 0.5 s of main-thread blocking inside the hero animation.
  - A 30-card collection page costs about 0.5–1 s of jank on a low-end phone.
  - On a slow mobile link, 5 × 50–80 KB may not arrive within 1.2 s. The flip then shows the hatched placeholder, which repeats the v2-3 "image only after the flip" bug.
- *Recommendation (architecture decision on AD-17 + spike):*
  - The package runs in a **Web Worker**: `fetch(url, {mode:'cors'})` → `createImageBitmap` → `OffscreenCanvas` downscale and quantise → `transferToImageBitmap` → `bitmaprenderer` canvas. Safari 16.4+ supports this, within `allow_browser :modern`.
  - Lazy-load with `IntersectionObserver` and a concurrency cap of 2–4 jobs.
  - **One palette per game**, computed once from the largest needed size and reused at every size. This gives consistent colours and less work.
  - The booster island starts fetching and filtering the five images as soon as the open response arrives, and does not let a card flip before its art is ready or has failed. A dealt card shows the back, so waiting costs nothing visible.
  - Optional, a product and legal call: compute the 32-colour palette (96 bytes) once at import and store it in `Catalog`. This is derived data, not a copy of the image, and it removes median cut from the client entirely.

**H2. The opening protocol (latency, refusal, double trigger) is not specified.**
- *Location:* EXPERIENCE.md › State Patterns "Opening refused" ("a toast … and nothing opens"), Motion "Booster opening … about 1.2s", Implementation notes ("Card content reaches the browser when the booster is opened"); AD-7 (p95 < 200 ms). The mocks draw the pack locally and start the explosion at once (`openPack`, l.1740).
- *Risk:*
  - If the explosion starts on click, a refusal or network error arrives after the caps have blown off, which contradicts "nothing opens".
  - If it waits for the response, the click feels dead for 100–300 ms on mobile.
  - A double click or Enter-repeat can fire two `OpenPack` calls. The second pack is credited but never shown.
  - The response must carry the five cards plus the new reserve and next-availability time for "OUVRIR LE SUIVANT", the counters and the packs chip.
- *Recommendation (spine fix + architecture):*
  - The request leaves on click. The **"ARMEMENT" charge phase (squash, orange LEDs, about 300 ms) masks the latency**. Caps blow only on success; on failure the canister disarms and the toast shows.
  - The island locks its trigger until the response arrives, and the endpoint takes an idempotency key per click (or the operation refuses a second open within N ms).
  - Define the JSON response:
    - the five cards: slug, title, publisher, genre, year, tier, number and image URL;
    - the reserve count and the availability times;
    - the per-tier counts before the opening, so the counters can tick at each reveal.

**H3. AD-16's "two islands" understates the client work; no contract links the islands and the server-rendered chrome.**
- *Location:* AD-16; EXPERIENCE.md › Component Patterns:
  - the rarity counter "updates as each card is revealed, never before";
  - the packs chip, the menu and tab-bar badges;
  - the toast region;
  - the daily-booster canister arcing to the packs chip;
  - card tilt and glare on every card;
  - the star field shifting between screens;
  - keyboard 1–6 and Esc;
  - phone sub-views sliding over.
- *Risk:*
  - The booster island is **two choreographies**: the desktop deal row, and the phone single card with the tray, swipe and caption plate, with an in-place rebuild on resize.
  - The rarity counter, packs chip and badges live in the server-rendered top bar and tab bar, outside the island. Teams will invent ad-hoc globals, which AD-16 forbids ("no global client store").
  - Every server-rendered card needs JS for its art (pixel filter) and its tilt.
- *Recommendation (architecture):*
  - **Islands:** booster (with a `layout: desktop|phone` mode) and trade board (with its picker and steppers).
  - **Stimulus controllers:** `card-art`, `tilt`, `starfield` (marked `data-turbo-permanent`), `countdown`, `ticker`, `hotkeys`, `dialog`, `toast`, `copy`, `back-picker`, `daily-claim`.
  - **A DOM event contract:** for example `gameble:tier-revealed {tier}`, `gameble:reserve-changed {count, nextAt}`, `gameble:toast {title, line, tone}` and `gameble:trade-badge {count}`. Islands dispatch these events and the chrome controllers listen.
  - The pixel filter, tilt and reduced-motion check are shared modules used by both Stimulus and React.

**H4. Screen-change motion and phone slide-overs do not come for free with Turbo Drive.**
- *Location:* EXPERIENCE.md › Motion:
  - "Screen change: the old screen slides 32px away … the new one slides in … the star field shifts sideways (1.1s). Panels then lock into place one after another (300ms each)";
  - "App start 340ms power-on flicker";
  - "Sub-views slide over their screen" on the phone;
  - "Coming back to the hub focuses the item last used";
  - "Opening in progress: Back, Esc and navigation are blocked".
- *Risk:*
  - Turbo Drive swaps the body, so the old screen no longer exists when the new one arrives.
  - Turbo's cached preview on back navigation replays the lock-in animations twice.
  - The flicker would play on every full load, including the return from Steam sign-in.
  - Staggered panel lock-in adds about 0.5–1 s of perceived latency on every visit.
  - Browser Back cannot be blocked.
  - A cached snapshot of the booster or trade page can show stale state.
- *Recommendation (architecture + spine fix):*
  - Use **View Transitions** through Turbo (`<meta name="view-transition" content="same-origin">`), with named transition groups for the screen slide. Browsers without support change instantly, as reduced motion does.
  - Keep the star field, scanlines and vignette as `data-turbo-permanent`.
  - Skip lock-in on Turbo previews (`html[data-turbo-preview]`) and cap the stagger at about 400 ms in total.
  - Play the power-on flicker once per session.
  - Mark booster and trade pages `turbo-cache-control: no-cache`.
  - Phone sub-views (card detail, trade board) are **Turbo Frames that advance the URL**, laid over the list that stays in the DOM. This keeps its scroll and makes Back natural.
  - Spine: "navigation is blocked during an opening" becomes "in-app back controls are disabled; browser Back is allowed and loses nothing" (cards are credited at opening).

**H5. The spines add server mechanisms and contract changes the architecture does not yet hold.**
- *Location:* ux-gameble.md › Changes; EXPERIENCE.md (presence, invitations, three-way visibility, card backs, NOUVEAU, numbering, ticker events); DESIGN.md (32 colours).
- *Risk:* The architecture spine is `status: final` but contradicts the spines in several places:
  - AD-17 says "reduction to **16** colours" (spine: 32).
  - The conventions name the tiers "steel, emerald, sapphire, amethyst, gold" (spine: Commune … Légendaire).
  - CAP-11 still lets the proposer set the expiry.
  - CAP-5 still says "two surprises per card".

  The new mechanisms have no home:
  - **Friends' presence**, including what a friend is doing: this needs connection tracking and an activity signal; nothing in the architecture provides it.
  - **Card backs**: unlock records, the active back, and the back art served to the booster island.
  - "NOUVEAU cleared when seen": a write triggered by a read request, which conflicts with AD-11's reading role.
  - A per-season card number.
  - Invitations as a pending state.
  - Profile visibility as a policy dimension.
- *Recommendation:* Run `bmad-architecture` in update mode with the list in "For the architecture" below before slicing the redesign epics. Run `bmad-spec` with ux-gameble.md's change list first.

### Medium

**M1. The 2 CSS px art pixel and the 2px lines go uneven at fractional device-pixel ratios.**
- *Location:* DESIGN.md `art-pixel: 2 CSS px`, `image-rendering: pixelated`, 2px rules and outlines. The mocks hide this with `fit()`, which snaps the stage scale to whole device pixels (l.2259). The fluid product cannot.
- *Risk:*
  - At a DPR of 1.25 (the Windows laptop default) or 1.75, and at some Android DPRs (2.625, 2.75), an art pixel is 2.5 or 5.25 device pixels.
  - Columns alternate 2/3 px, and box-shadow outlines blur. This hits "fine pixel art", the identity's first idea.
- *Recommendation (spike):* Measure on a 125% Windows laptop. Options:
  - Accept the unevenness.
  - Size each art canvas's backing store to `round(2·dpr)` device px per art pixel, and adjust the CSS box to `n·round(2·dpr)/dpr`. Cards then vary by under 1 CSS px per DPR.
  - Snap only the large cards.

  Record the choice in DESIGN.md.

**M2. The pixel fonts lack the interface glyphs the copy uses.**
- *Location:*
  - DESIGN.md › Typography;
  - the copy "◀ PONT", "TOUT VOIR ▸", "VOIR SUR STEAM ↗", "⇄ ÉCHANGE", "✕", "COPIÉ ✓", "◆" (ticker);
  - numbers grouped as "31 420".
- *Risk:*
  - `fc-query` shows Silkscreen, Pixelify Sans and VT323 all lack ◀ ▶ ▸ ◆ ⇄ ↗ ✕ ✓ and U+202F.
  - U+202F is the group separator `Intl.NumberFormat('fr')` emits.
  - These fall back to system fonts with mismatched metrics.
  - ◀ ▶ can render as colour emoji on iOS and Android without U+FE0E.
- *Recommendation (spine fix):*
  - Draw these as pixel SVG icons in an icon component; the mocks already do so for rarity shapes.
  - Group digits with U+00A0, which all three fonts have, and never with U+202F.
  - Note the rule under Typography.

**M3. The documented CORS fallback can never trigger as coded.**
- *Location:* DESIGN.md: "If the CDN refuses cross-origin reads, the downscaled image is kept without the colour reduction"; mocks `im.crossOrigin='anonymous'` then `try{quantize}catch{}` (l.1256–1267).
- *Risk:*
  - With `crossOrigin` set and no ACAO header, the **load itself fails** (`onerror`), so the card shows "IMAGE INDISPONIBLE". The try/catch only covers a tainted canvas, which this code never produces.
  - CORS works today. Behaviour after a CDN change is undefined, and it is a single point of failure.
- *Recommendation (package rule):*
  - On a CORS failure, retry once without `crossOrigin`, and draw the tainted image scaled with `pixelated` and no palette.
  - Do not cache failures for the whole session: `IMGP` caches `null` forever, so one network blip leaves "IMAGE INDISPONIBLE" until reload. Retry on the next mount.
  - Never add request headers to image fetches. Preflight answers 405, and tracing SDKs must exclude the Steam hosts.

**M4. The continuous-animation and paint budget is unbounded, especially on the hub and on phones.**
- *Location:*
  - DESIGN.md › Elevation & Depth and Rarity effects;
  - mocks `scan` (full-viewport `background-position`, steps(3) every 0.6 s), `tcgHolo` / `tcgFoil` (`background-position` on `mix-blend-mode` overlay / color-dodge layers), `segCur` (background), 54 individually animated stars;
  - `bFrame` (l.1770), a `requestAnimationFrame` loop that runs forever on every screen and writes `style.transform` on each dealt card every frame, even when idle.
- *Risk:*
  - `background-position` animations repaint on the main thread. A full-viewport scanline repaint 5 times a second on a 4K or phone screen, plus blend-mode render surfaces under 3D tilt, costs battery and drops frames.
  - The hub stacks more than 10 infinite loops: rays, pedestal, idle float, ground shadow, LEDs, badge pulse, gauge segment, ticker, scanlines, stars, colons, and holo/foil when the showcase is a Légendaire.
- *Recommendation (spine rule + build rule):*
  - Every infinite loop animates only `transform` or `opacity`. Scanlines become a static gradient on an oversized layer moved by `translateY` steps, or a static one. Holo and foil animate a transformed gradient child, not `background-position`.
  - rAF loops run only while something moves, and stop on `visibilitychange` or when off-screen.
  - Offscreen grid cards get `content-visibility: auto`.
  - Set a budget, for example "at most 6 infinite animations visible per view on the phone; holo and foil only on cards in the viewport".
  - Spike on a low-end Android (e.g. a Galaxy A14 or Moto G class device, with Chrome remote DevTools): the Légendaire sequence, the trade swap and an idle hub at 60 fps.

**M5. `touch-action: none` on large cards traps scrolling on the phone.**
- *Location:* mobile.html: `.show` (hub showcase 208 × 312), `.d-card` (detail), `.pub-card` (public page) and `.z-card` are `touch-action:none`, so a held finger can tilt them. `.chips` is `pan-x`.
- *Risk:* On a 390px-wide scrolling column, a drag that starts on the showcase or the public card does not scroll the page. On the public page, the card is most of the first screen.
- *Recommendation (spine fix in Interaction Primitives):*
  - Cards in scrolling content use `touch-action: pan-y`. The tilt follows only a horizontal drag or a long press; the detail's horizontal swipe still works.
  - `none` is kept only on the booster stage.
  - Chips use `pan-x pan-y`.

**M6. The mocks' code is not safe to port into Turbo or Stimulus lifecycles.**
- *Location:* key-screens.html and mobile.html:
  - 53 and 68 `addEventListener` calls, 0 `removeEventListener`;
  - `setInterval(tick,1000)` never cleared;
  - document-level `keydown` and window `resize` listeners;
  - module-level mutable state (`S`, `FX`, `TILTS`, `IMGP`, `ARTP`);
  - unbounded caches.
- *Risk:* Turbo visits reconnect controllers without a reload. Copied listeners and intervals pile up with every visit: duplicate ticks, double Esc handling, and memory growth with decoded 600 × 900 images held in `IMGP`.
- *Recommendation (build rule, add to EXPERIENCE.md › Implementation notes):*
  - Mocks are a reference for look and timing, never source to copy.
  - Every listener and timer is registered in `connect()` or in an effect and removed in `disconnect()` or the cleanup. Prefer Stimulus `data-action="keydown@document->…"`.
  - Image caches are LRU-bounded and keep filtered bitmaps, not source images.

**M7. i18n inside the islands needs interpolation and French/English plural rules.**
- *Location:* AD-16 ("translated strings as props"), AD-18. Strings involved:
  - "Cliquez une carte pour la révéler · n restantes", "Cartes révélées : n / 5";
  - "Carte 2 sur 5, face cachée. Révéler.", "2 RÉSERVÉES", "1 carte · 2 ex.";
  - "Expire dans n j", "Il y a 3 h", "/max";
  - the state words, the banners "LÉGENDAIRE !".
- *Risk:* Pre-translated props cannot hold counts. French treats 0 as singular and English does not. Every island would grow its own ad-hoc formatter.
- *Recommendation (architecture):*
  - Islands receive a scoped key → template map, with `one`/`other` forms and `%{n}` placeholders, generated from the Rails locale files at render.
  - A tiny shared `t(key, vars)` uses `Intl.PluralRules` and the U+00A0 rule from M2.
  - Relative times are server-rendered `<time datetime>` refreshed by a Stimulus controller with `Intl.RelativeTimeFormat`.
  - Keep strings in natural case in the locale files and uppercase with CSS (with `lang` set), so English casing stays editable.

**M8. No Content-Security-Policy is defined; the redesign widens what one must allow.**
- *Location:* `config/initializers/content_security_policy.rb` (entirely commented out); the mocks load Google Fonts.
- *Recommendation (architecture):* Adopt a policy now. `img-src 'self' data: blob: https://*.steamstatic.com https://steamcdn-a.akamaihd.net` (covers the avatars if used). `connect-src 'self'` + the same Steam hosts (`fetch()` in a worker counts as connect), + the Action Cable `wss:` origin. `worker-src 'self' blob:`; `font-src 'self'` (fonts self-hosted, no Google Fonts: privacy). `style-src 'self'` with a nonce. Server-rendered `style="width:…"` attributes (progress bars, gauges) are blocked without `'unsafe-inline'`, so set them as CSS custom properties from Stimulus. CSSOM writes from JS are allowed. `script-src 'self'` with nonces; the Vite dev server is allowed only in development. Run the policy report-only for one release.

**M9. The 3D pitfall is narrower than the actual rule.**
- *Location:* EXPERIENCE.md › Implementation notes ("Never put 3D transforms on a `<button>`…").
- *Risk:* Grouping properties force `transform-style: flat` and bring back the mirrored back. These are `opacity` < 1, `filter`, `overflow` other than visible, `clip-path`, `mask`, `mix-blend-mode`, `isolation`, `contain: paint` and `will-change: opacity/filter`, on the tilt or flip layers or between them. The mock dims cards with `filter:brightness(.32)` on `.bx-travel` (l.382), one level above the 3D layers. One refactor that moves it down reintroduces the v2-3 bug.
- *Recommendation (spine fix):*
  - Extend the note: "no grouping property on `.tilt`/`.flip` or between them; dim, fade or blur a sibling overlay or an ancestor outside the 3D context".
  - Add a visual regression test of a tilted, revealed card.

**M10. Some tokens are not CSS values, and one is ambiguous.**
- *Location:* DESIGN.md frontmatter:
  - `panel.border: inset 2px` (read literally, CSS `border: 2px inset` draws a two-tone bevel; the mocks use `box-shadow: inset 0 0 0 2px`);
  - `bevel: inset 3px white 35% top-left…`, `card-back.sheen: 'a pale accent band sweeps…'`, `idle-float: 2px over 14s`, `hazard-stripe.pattern`;
  - "pixel outline drawn as four hard offsets" (which offsets?);
  - `blink: 1s steps(1)` (DESIGN) versus the mocks' 0–49% / 50–100% keyframes.
- *Risk:* The developer turning tokens into CSS variables guesses, and the three outline widths (4 / 3 / 1 px) drift.
- *Recommendation (spine fix):* Give each of these the exact CSS value from the mocks, for example `--outline-card: 0 -4px 0 0 #06090d, 0 4px 0 0 …` or the mocks' exact `box-shadow` list, and `--panel-border: inset 0 0 0 2px var(--line)`. Move the prose effects to a "Effects" section with their CSS recipe. State the custom-property naming (`--colors-accent` or `--color-accent`; epic 1 uses `--color-*`).

**M11. The card backs, canister, icons, avatars and logo exist only as procedural drawing code in the mocks.**
- *Location:* mocks `backCanvas(id,…)` → `toDataURL` (l.1141), the canister canvases (l.1552–1557), `iconSVG`, the avatar and achievement pixel maps; DESIGN.md › Card backs ("drawn pixel by pixel").
- *Risk:* Two bad paths. Production either ships hundreds of lines of runtime canvas drawing, which costs JS weight and main-thread time at every page load, or someone redraws eight backs by hand and they drift from the approved art.
- *Recommendation (architecture + task):* A one-off script renders each procedural asset at 1× art resolution to PNG (or SVG for icons). The files are committed under `app/frontend/images/pixel/` and displayed with `image-rendering: pixelated` at 2 CSS px. Backs become static assets referenced by key, which also gives the booster island a simple URL for the active back. The author reviews the exported sheet once.

**M12. The phone shell model (inner scroll versus document scroll) and the safe areas.**
- *Location:* mobile.html (`.screen{position:absolute…overflow:hidden}` with inner scroll; `viewport-fit=cover`); DESIGN.md "tab bar plus the safe area"; epic 1's layout `<meta name="viewport" content="width=device-width,initial-scale=1">`, which has no `viewport-fit=cover`.
- *Risk:*
  - Without `viewport-fit=cover`, `env(safe-area-inset-*)` is 0 on iOS.
  - An app shell with inner scroll containers breaks Turbo's scroll restoration (it restores window scroll only), stops the iOS URL bar from collapsing, and adds `100vh` bugs.
- *Recommendation (spine + architecture):*
  - Document scroll, with the top bar `position: sticky` and the tab bar `position: fixed` with `padding-bottom: env(safe-area-inset-bottom)`.
  - `viewport-fit=cover`; `dvh` units where a full height is needed (the booster stage).
  - Slide-over sub-views per H4.

### Low

**L1. One palette per size.** The same card can show different colours at s and xl, because each size runs its own median cut. Fix it with the per-game palette from H1.

**L2. The collection grid's arrow keys hard-code 5 columns.** The mock uses `ArrowDown:5` (l.2286), and fluid grids break it. The spine already says "whatever the column count". Implement it by comparing `offsetTop` values or by using the computed `grid-template-columns`.

**L3. Esc precedence is spread across components.**
- *Precedence:* Esc closes a dialog, then cancels a counter-proposal edit, then goes back to the hub.
- *Risk:* A native `<dialog>` handles Esc itself, while a document-level hotkeys controller also sees the keydown. One Esc then closes the dialog and also navigates.
- *Recommendation:*
  - Use native `<dialog>` with `showModal()` for every modal and bottom sheet, in both Stimulus and React. It gives inert background, focus trap and Esc for free.
  - The hotkeys controller ignores events with `defaultPrevented`, events with an open dialog, and events from form fields.
  - Single-key shortcuts 1–6 need a way to turn them off (WCAG 2.1.4). Point the accessibility review at this.

**L4. The LIVE ticker and live updates.** The mock's ticker is a duplicated strip animated with `translateX(-50%)`. Inserting broadcast items mid-loop makes it jump. Apply incoming Turbo Stream items only on `animationiteration`, and pause on hover as the spine says.

**L5. Pixel fonts at sizes off their grid.**
- *Sizes:* Silkscreen at 7–14px and Pixelify Sans at 600, a variable instance between masters.
- *Risk:* These render antialiased, not crisp. Approved as seen in the mocks, but worse at fractional DPR (see M1).
- *Loading:*
  - Self-host subsetted woff2 files (Latin + Latin-1 + Latin Extended-A).
  - Preload the three files.
  - Use `font-display: block` with a short block period, because a fallback swap reflows the two-line card titles.
- *Records:* Move the `[ASSUMPTION]` on font files to a decision, and record the three licences (OFL).

**L6. Hotlinking dependence.**
- *Risk:* Valve could add referer checks or change hosts.
- *Mitigation:*
  - Build every URL from the import data (C1).
  - Keep the host swap in one config value.
  - Send image requests with `referrerPolicy: 'no-referrer'`, which costs nothing.
  - Never put covers in a service worker, Cache Storage or IndexedDB. The spec says images are never stored, and the HTTP cache is enough given Steam's `Cache-Control`.
  - If the PWA service worker (`app/views/pwa/service-worker.js`) is ever enabled, exclude the Steam hosts.

**L7. Countdowns and pack credit on the client.**
- *Countdowns:* "+1 dans", "PROCHAIN DANS" and expiry.
- *Risk:* These need the server clock offset and the bank's availability times (AD-7 runs no per-player job). Otherwise the chip shows wrong numbers on a skewed device clock.
- *Recommendation:* Pass `server_now` and the list of availability times. The client increments the reserve locally when a time passes, and the server stays the authority on open.

**L8. Accessibility details that touch implementation.** For the accessibility review:
- Art canvases and the FX canvas are `aria-hidden` (the mocks' `#fx` is not).
- A reveal changes the focused card's accessible name. Screen readers rarely announce that, so also send "Légendaire : Hollow Knight, 2017" to the polite live region.
- No text is ever drawn into a canvas (the banners are DOM, keep it so).

**L9. The pedestal drifts 6px.** `.pedestal{animation:drift 8s}` (6px, l.218) breaks the "idle float 2px at most" rule. The unused `bob` keyframes (10px) should not be ported.

**L10. `allow_browser versions: :modern`.**
- *Effect:* The ApplicationController sends older browsers to a 406 page. Rails' `:modern` means Safari 17.2+, Chrome 120+ and Firefox 121+.
- *Impact:* This covers OffscreenCanvas, `inert`, `<dialog>` and View Transitions fallbacks, but it shuts out iPhones stuck on iOS 16.
- *Recommendation:* State the supported-browser floor in EXPERIENCE.md › Responsive & Platform, so the low-end test device is chosen inside it.

**L11. The daily-booster arc and Turbo Streams.**
- *Flow:* "RÉCUPÉRER" posts a Turbo form, and the stream replaces the panel and the packs chip.
- *Risk:* The arc needs both positions before the DOM is replaced.
- *Recommendation:* Run it from `turbo:before-stream-render`, or animate from the response and replace afterwards, and send `gameble:reserve-changed` (H3).

**L12. Grid scale.** Publisher sets for large publishers can hold far more than the mock's 30 cards. Paginate (Pagy) or virtualise the collection grid beyond about 60 slots, and filter only visible cards (H1).

## For the architecture

What the spines decide and `bmad-architecture` must absorb (update mode; the spine is marked `final` but is now out of date):

1. **AD-17 rewritten:**
   - 32 colours, median cut, no dither, 2 CSS px, crop anchored at 42%.
   - Runs in a Web Worker with OffscreenCanvas; lazy, with a concurrency cap.
   - One palette per game; no-CORS fallback (M3); placeholder detection (C1).
   - An LRU in-memory cache only, never persistent storage.
   - Optionally, palettes computed at import (H1).
2. **Image source (C1):**
   - The `Steam` import stores the hashed vertical-capsule URL and refreshes it periodically.
   - The CAP-2 exclusion is tested on API assets.
   - `Catalog` exposes `image_url`.
3. **AD-16 detailed:**
   - Two islands: booster (desktop and phone choreographies, resize rebuild) and trade board (picker, steppers, swap).
   - The named Stimulus controllers.
   - The DOM event contract between islands and chrome (H3).
   - Shared TS modules: filter, tilt, motion and reduced motion, `t()`.
4. **Opening endpoint contract (H2):**
   - Request on click; the charge phase masks the wait; idempotency key.
   - Response: five cards, the reserve with its availability times, `server_now` and the pre-open tier counts.
   - The error codes it returns.
5. **Navigation and motion on Turbo (H4):**
   - View Transitions through Turbo; permanent atmosphere layers.
   - Previews skip lock-in; `no-cache` on booster and trade pages.
   - Phone sub-views as URL-advancing Turbo Frames over a list kept in the DOM.
   - Document scroll, not an app shell (M12).
6. **Layout system (C2):**
   - The breakpoints, the max width, and the short-viewport behaviour.
   - A fixed logical booster stage; phone landscape.
   - Plain CSS with container or media queries; tokens as custom properties with the M10 values.
7. **Real-time:**
   - Per-player Turbo Stream channel for trade badges and invitations.
   - Public feed and gauge streams (already in AD-13).
   - Ticker updates at loop boundaries.
   - **Friends' presence**: connection tracking, an activity signal, and a throttled last-seen write on the player's own row (AD-9 compliant).
8. **New domain data:**
   - Card backs (catalogue of backs, unlocks, active back) and their unlock handlers on events: set completed, goal contribution, achievements, events.
   - Invitations (pending, accepted, ignored).
   - Three-way profile visibility in policies.
   - A per-season card number on `catalog_card_seasons`.
   - The first-listed Steam genre on cards.
   - "Seen" state for NOUVEAU, written by an explicit operation or a beacon, not inside a GET on the reading role.
   - Trades: fixed 7-day expiry; counter-proposal edits both sides; at most 4 distinct cards per side.
9. **Conventions:**
   - Rename the tiers to Commune / Peu commune / Rare / Épique / Légendaire. Code identifiers could be `common, uncommon, rare, epic, legendary`, with the French names in locale files.
   - The card-number format "S1 · #4 215" with U+00A0.
10. **CSP (M8)**, and the fonts self-hosted (no Google Fonts).
11. **i18n in islands (M7):** templates, plurals, relative time, CSS uppercase.
12. **Static pixel-art assets (M11):** an export script and a folder convention.
13. **Performance budget and a reference low-end device**, with a spike before the booster story (M4, H1). Add the browser floor (L10).
14. **Housekeeping:**
    - The architecture cites `../spec-gameble/stack.md`, which does not exist.
    - Its `sources` still include the superseded spines; refresh them after the spec update.

## Epic 1 rework

What the built code (branch `ux-redesign`, from the medieval direction) must change:

1. **`app/frontend/styles/tokens.css`:**
   - Replace the parchment, leather, brass and dust palette and the steel→amethyst rarity tokens with DESIGN.md's colours: 5 tiers × 3 shades, typography, spacing (including `topbar-height`, `ticker-height`, `tabbar-height`, `touch-min`) and the motion easings.
   - Fix the naming convention (M10).
2. **Fonts:**
   - Remove Jost (`app/frontend/fonts/jost-*.woff2`, `styles/fonts.css`).
   - Add subsetted woff2 files of Pixelify Sans (600, 700), Silkscreen (400) and VT323 (400), with their OFL texts; preload them.
   - Epic R5 says "the typeface is Jost": update the epic text.
3. **Remove the attic:**
   - `app/views/pages/home.html.erb`, `styles/attic.css`, `controllers/attic_controller.ts`, `test/system/attic_test.rb`.
   - Replace them with the hub "Pont de commandement", desktop and phone variants, including the signed-out hub (still unmocked: see the spine's open questions).
   - `SampleIsland` and its system test can stay as the Turbo Mount smoke test, or be replaced by the booster island skeleton.
4. **`layouts/application.html.erb`:**
   - The status band becomes the top bar: logo or back button, rarity counter, packs chip, player chip or "SE CONNECTER AVEC STEAM".
   - Add the LIVE ticker slot (hub), the phone tab bar, and permanent star field, scanline and vignette layers (not in the back-office).
   - Add a toast live region, which replaces the `.flash` block (flash messages become toasts: bottom centre on desktop, top on the phone, 2.8 s).
   - Add `viewport-fit=cover` and `theme-color`, and the `view-transition` meta.
5. **`ButtonComponent`:**
   - Variants primary (lime), secondary, danger, disabled, small, back and Steam sign-in, plus a link style.
   - Pixel outline, bottom inset, lift and press.
   - The "one lime per view" rule cannot be enforced by the component; a system test can check it.
   - Update `button_component_test.rb`.
6. **`TextPlateComponent`:** it is a parchment plate. Replace it with `PanelComponent` (panel, quiet panel, corner brackets option) and add Kicker, LED, Gauge and Toast components.
7. **Locale files (`config/locales/fr.yml`, `en.yml`):** rewrite all copy.
   - It uses "tu", "Confrère", "S'enrôler", "Quitter les rangs", "Retour au grenier", "grenier", "scribes", "registre". The spines require "vous", no title, terminal labels, and Brotherhood only on the community goal.
   - Reconsider the `<title>` "La Grande Confrérie des Gamblers".
   - Update the tests that assert this copy: `pages_controller_test.rb`, `authorization_test.rb`, `sessions_controller_test.rb`, back-office tests.
8. **Focus style:** the `:focus-visible` ink outline becomes the 3px `{colors.accent}` ring, gold on cards in grids.
9. **Back-office shell:** restyle with the new tokens, panels and buttons, and no atmosphere layers. Its back button now reads "◀ PONT".
10. **Sign-in landing:** R9 "lands on the attic page" becomes the hub, and the epic and story text change to match.
11. **CSP:** enable `config/initializers/content_security_policy.rb` per M8 (report-only first).
12. **Tickets:** update `story-attic-page-shell` and the epic's R5 and R9 texts and their references (`mockups/attic.html` is retired), so the board does not point to the old direction.
