# Review — versions and rubric, economy charts update (2026-11-10)

Scope: AD-51 (new), the amendments to AD-16 and AD-48, the Stack row for chart.js and the Deferred entry "Later economy charts". Read against AD-9, AD-11, AD-13, AD-15, AD-16, AD-18, AD-27, AD-30, AD-40 to AD-50, the validated mockup `ux-gameble/.working/market-charts.html`, `.memlog.md`, `package.json`, `vite.config.ts`, `tsconfig.json`, `app/frontend/entrypoints/application.ts`, `app/frontend/lib/i18n.ts` and `config/initializers/content_security_policy.rb`.

**Verdict: pass with fixes.** The library choice holds: chart.js 4.6.1 exists, is current, fits Vite and TypeScript, and needs no CSP change. No critical finding. Four high findings are divergence points AD-51 leaves open or decides against an existing AD; each needs one or two lines in the spine before the first chart story.

## Lens 1 — Versions and fit

Evidence gathered with `npm view`, `npm pack chart.js@4.6.1` (dist inspected), the GitHub releases API and a rolldown bundle probe.

| Claim AD-51 relies on | Result | Evidence |
| --- | --- | --- |
| chart.js 4.6.1 exists and is current | True | npm `latest` = 4.6.1, published 2026-10-22 (19 days old: passes the two-week rule). MIT. One dependency, `@kurkle/color ^0.3.0`. |
| Release line | Note | 4.6.0 was tagged on GitHub 2026-10-22 but never reached npm; 4.6.1 is "trusted publishing fix + version bump". npm goes 4.5.1 → 4.6.1. 4.6.0's changes (integer canvas dimensions, stack fix, types) ship in 4.6.1. No breaking change. |
| Ships ESM with TypeScript types | True | `"type": "module"`, `exports["."]` = `{ types: ./dist/types.d.ts, import: ./dist/chart.js }`. Resolves under the app's `moduleResolution: "bundler"`; `skipLibCheck: true` shields TypeScript 7.0.2 from any d.ts quirk. |
| Tree-shakes with explicit registration under Vite | True, gain modest | `sideEffects` lists only `auto/*` and UMD files. Probe (rolldown 1.2.15, minified): Bar, Line, Scatter controllers + Bar/Line/Point elements + Linear and Category scales + Tooltip + Legend = 174 KB / **59.6 KB gzip**; `chart.js/auto` = 205 KB / **69.2 KB gzip**. The lazy boundary (dynamic import) matters more than the registration list. |
| Dynamic import under Vite and the CSP | True | Precedent: `clerk_sign_in_controller.ts` already does `await import("@clerk/clerk-js/no-rhc")`. Chunks load from `'self'`. |
| Works under the production CSP without `'unsafe-inline'` styles | True | 4.6.1 dist has no `createElement('style')`, no `setAttribute('style', …)`, no `cssText`, no `insertRule`, no `eval`/`new Function`. `initCanvas` writes `canvas.style.display`, `.boxSizing`, `.width`, `.height` and `style.setProperty('direction', …)` through CSSOM, which CSP does not block; `releaseContext` restores them the same way and sets only `width`/`height` attributes. Tooltip and legend are drawn on the canvas, not in DOM. |
| Scatter | True | `ScatterController` exported. |
| Stacked bars with negative values | True | Stacking per scale `stacked: true`; negative values stack below zero (mockup already does it, with `Math.abs` in the tick callback). |
| Mixed bar/line | True | Per-dataset `type` on a bar or line chart. |
| pointStyle per dataset: circle, rectRot, triangle, star | True | `drawPoint` handles `triangle`, `rectRot`, `star`; `circle` is the default branch. Per-dataset `pointStyle` option. |
| Linear or category x-axis without a date adapter | True, but see H4 | `LinearScale` and `CategoryScale` need no adapter. `TimeScale`/`TimeSeriesScale` throw "This method is not implemented: Check that a complete date adapter is provided." without one. AD-51 does not say which axis type a time series uses. |

Nothing AD-51 assumes about the library is false. The memlog's CSP statement ("Chart.js sets canvas size through CSSOM, which CSP allows") is confirmed in code.

One residual CSP point, low risk: Turbo's page cache clones the DOM before the chart controller disconnects, so a cached snapshot carries the canvas with Chart.js's `style` attribute. A cloned node is not re-parsed, so the CSP is not consulted; still, watch the Sentry CSP reports after the first release with a chart (see M3 for the sizing side of the same issue).

## Lens 2 — Rubric

### High

**H1. Number formatting contradicts AD-18 and AD-40.** AD-51: "The browser formats it (`Intl`, in the page locale)". AD-18: "Numbers are formatted by one helper on each side that groups digits with U+00A0" — in the browser that helper is `formatNumber(value, delimiter)` in `app/frontend/lib/i18n.ts`, fed a delimiter by the server. AD-40: "every amount goes through one `picoins` helper giving the compact form". `Intl.NumberFormat("fr")` groups with U+202F (the mockup's `fr.format` does exactly this), and nothing in the browser produces the `picoins` compact form ("412,6 M"). Two units (tick callback, tooltip, headline) will format three ways.
*Fix:* replace the `Intl` clause with: chart numbers go through `i18n.ts`'s `formatNumber` with the server's delimiter, and amounts through one browser `picoins` formatter tested against the Ruby helper's fixtures; dates come from the server as labels (a UTC day, so no browser time zone shift).

**H2. The edition's running average is defined differently from the validated mockup, and costs a quadratic GET.** AD-51: "at each sale, the average `EditionPrice` gives over the sales up to it" (sales within the *current* window). Mockup: "le prix moyen tel qu'il était calculé au moment de chaque vente". They differ for every early point (the then-window held sales the current window drops) and after any change of the window setting (AD-42). Recomputing `EditionPrice` per prefix on each card-page GET is O(n²) per render, and the line's last step can disagree with the stored `game_market_edition_prices` row once the nightly job moves the window.
*Fix:* the settlement (AD-45), which already upserts the edition price, stores the average it computed on the listing (`average_after_sale`); `EditionSales` reads `sold_at`, `final_price` and that column, and never calls the formula.

**H3. Derived figures and signs are left to the browser.** The validated mockup shows headline figures (in circulation, minted over 30 days, destroyed over 30 days, destroyed/minted ratio), destroyed bars below zero, and windows of 30 days (Reactor) and 90 days (prices, back-office, edition). AD-51 lists the per-day series only, so whoever builds the page will sum, divide and negate in TypeScript, which its own first rule forbids; and two units can pick different windows.
*Fix:* `EconomySeries` returns the destroyed series already negative, the summary figures per chart, and takes the window as a named constant per chart (30, 90); the browser only formats.

**H4. The x-axis is not fixed.** Without a date adapter `type: "time"` throws, so the first builder of a time series either adds `chartjs-adapter-date-fns` (a second dependency, not in the Stack) or picks category or linear; the Reactor's two stacked charts and the scatter would then diverge.
*Fix:* add "No date adapter. Daily series use a category axis with one server-rendered label per UTC day; the edition scatter uses a linear axis over epoch milliseconds whose ticks are formatted from server-provided templates."

### Medium

- **M1. The lazy boundary is not protected.** Controllers are registered eagerly (`import.meta.glob(..., { eager: true })`), so a value import from `chart.js` in any `lib/charts/*` module lands Chart.js in the main bundle. State: kind modules import only types from `chart.js`; one module registers the needed components explicitly and is reached only through the dynamic import; never `chart.js/auto`.
- **M2. `floor` is a JSON key with no source.** The validated mockup draws the rarity floor (dashed) on the edition chart; the memlog lists "the floor line" as later; neither `EditionSales` nor Deferred says where the floor comes from (current settings version, AD-42). Either drop the key and defer the line, or name its reader.
- **M3. Canvas sizing and Turbo cache are undecided.** Chart.js's responsive mode needs a dedicated, CSS-sized container (4.6.0 added a doc note on flex/grid layouts); the cached Turbo snapshot keeps Chart.js's `width`/`height` attributes and inline size, which can make a restored chart grow. Decide: a wrapper class sized by CSS, `maintainAspectRatio: false`, and destroy on `turbo:before-cache`. Two charts "on a shared time axis" also need a fixed y-axis width to line up.
- **M4. Reduced motion (AD-27) is not mentioned.** Chart.js animates on load and update by default; state that the controller sets `animation: false` when the shared reduced-motion switch is on.
- **M5. "A `<details>` table of the same rows" contradicts the mockup.** The mockup's tables show the last 7 days and a three-column index summary, not 90 rows per rarity. Decide which, per chart.
- **M6. Legend, tooltip and axis strings have no stated path.** Series carry meaning keys; their names (rarity names included) and tooltip templates should reach the controller as AD-18 templates in a Stimulus value, from the locale files.
- **M7. Gaps are unspecified.** A missing snapshot day, a rarity with no price yet, a day with zero median earnings (division by zero for days of income). State: one row per UTC day in the window, `null` where there is no figure, drawn as a gap (`spanGaps: false`).
- **M8. Publishing a chart is an operation without a named event.** AD-10 and the repo rules require one event per state-changing operation (`Game::Market::ChartPublished` / `ChartUnpublished`), a unique key on the publications table, and an answer for publishing twice.

### Low

- **L1.** "The four back-office indicator series" are unnamed; name them as in `market-economy.md`, and say whether their threshold line is the current threshold or the one in force each day.
- **L2.** "The card page" is ambiguous: the collection card detail, the public share page (AD-15, AD-39), or both.
- **L3.** Index base: AD-51 says 100 at each rarity's first snapshot with a price; the mockup copy says "base 100 à l'ouverture du marché". Align the copy.
- **L4.** Rarity shapes as CSS custom properties work (`getPropertyValue(...).trim()` gives `rectRot`) but are unusual; say whether shapes live in CSS or in one TypeScript map keyed by rarity code.
- **L5.** Chart.js defaults to Helvetica; resolve the `--font-*` token and wait for `document.fonts.ready` before the first draw, or canvas text falls back.
- **L6.** The mockup uses a custom end-label plugin; say custom plugins live in `lib/charts/` and are registered per chart, never globally.
- **L7.** Caching of the public economy page and the card chart is neither decided nor deferred; add a Deferred line (e.g. `Rails.cache` keyed by the last snapshot day, only if measured).
- **L8.** Tests: AD-22 policies for the economy page (visitor not found while unpublished, staff sees it), a system test for the publication switch; happy-dom has no 2D context, so Vitest covers the pure kind modules only — say so.
- **L9.** AD-51 carries no `[ADOPTED]` tag and no Costs line, unlike AD-40 to AD-50 (Costs: a new table, a snapshot column, a listing column if H2 is applied).
- **L10.** Stack row could note that `chartjs-adapter-date-fns` (3.0.0) is deliberately not added, which makes H4 enforceable at review.

### Consistency with existing ADs

- AD-9, AD-11, AD-13, AD-15: consistent (reading-role queries, no broadcast, no id in the JSON).
- AD-16: the amendment is consistent; a canvas is already an allowed script-built node, and Chart.js writes no `style` attribute in server HTML.
- AD-18, AD-40: contradicted on number formatting (H1).
- AD-27: silent on reduced motion (M4); CSP clause holds.
- AD-30: not engaged; a chart is one controller, not a rich screen. Fine.
- AD-41, AD-48: "destroyed counting stamps, commissions and forfeits" plus circulation from the reconciliation's global sum matches AD-41's invariant; the bars reconcile with the line.
- AD-42: the window and the floor read settings; affected by H2 and M2.
- AD-45, AD-47: H2 proposes the settlement store the running average, which keeps `EditionPrice` the only formula.

### Dimensions

| Dimension | State |
| --- | --- |
| Data | Decided, except summary figures, signs and windows (H3), gaps (M7), floor (M2), running average (H2). |
| Rendering | Decided for library, component and controller; open: axis type (H4), sizing and Turbo cache (M3), fonts (L5), plugins (L6). |
| Accessibility | Decided (role, label, table); open: reduced motion (M4), table content (M5). |
| Caching / performance | Lazy load decided; bundle boundary (M1) and page caching (L7) open. |
| Publication | Decided; event and idempotency (M8). |
| i18n | Copy keys decided; number formatting contradicts AD-18 (H1); series names (M6). |
| Tests | Vitest for kind modules stated; policies and system tests unstated (L8). |
| Rollout | Implicit: charts ship unpublished, back-office charts appear once snapshots exist; the market is not built, so the snapshot column ships with the table. Acceptable; could be one line in AD-50's rollout. |

### Deferred

"Later economy charts" cannot let two units diverge: market-wide ones must extend `EconomySeries`, per-player ones wait for an update run. No issue.
