---
title: 'Pixel-art image filter package'
type: 'feature'
ticket: '4'
created: '2026-10-02'
status: 'built'
baseline_revision: '6891e36fd0789b9e1669df9165148b3f79693c9d'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/ux-gameble/DESIGN.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Card art must be the game's vertical Steam image, pixelated to the art grid and reduced to 16 colours computed per image, in the browser, and nothing does it yet (epic 3, R6; AD-17; DESIGN.md, Card art).

**Approach:** Create `packages/pixel-art-filter`, a standalone TypeScript package with no dependency on gameble: a pure core that centre-crops, downscales and reduces RGBA pixels to at most N colours (no dithering), and a browser helper that loads an image cross-origin and draws the result on a canvas at grid size. Add Vitest and run the package's tests in CI.

## Boundaries & Constraints

**Always:**
- Types: `Pixels = { width: number; height: number; data: Uint8ClampedArray<ArrayBuffer> }` (RGBA). Sizes and `colors` are validated: positive integers, `colors` 1–256, data length = w × h × 4; otherwise `RangeError`.
- `pixelate(source, width, height, { crop = "cover" })`: centre-crops the source to the target ratio (`"cover"`; `"none"` stretches), then box-filters: each target pixel is the area-weighted mean of the source pixels it covers, alpha-weighted (premultiplied) for RGB, each channel `Math.round`ed; a source smaller than the target falls to the covering pixel (nearest). Alpha is then made binary: ≥ 128 → 255, else 0 (and RGB 0).
- `quantize(pixels, colors = 16) → { palette, pixels }`: median cut over the histogram of unique opaque colours with their counts. Box to split next: the largest `range × population` (ties: lowest box index); channel: the largest range (ties R, G, B); colours sorted stably by that channel then the others; split at the population median moved to the nearest boundary where the channel value changes; a box with zero range is not split; stop at `colors` boxes or when none can be split; if there are no more unique colours than `colors`, the palette is exactly those colours. Palette entries are the `Math.round`ed population-weighted means, in box order; each opaque pixel maps to the nearest entry by squared RGB distance (ties: lowest index); transparent pixels stay transparent and out of the palette. Same input, same palette and pixels.
- `filter(source, { width, height, colors = 16, crop = "cover" })` = `pixelate` then `quantize`. The caller passes the grid size; the art-window size belongs to the card component (story 3.5).
- `renderArt(url, canvas, { width, height, colors, signal? })`: touches DOM globals only when called; sets `crossOrigin = "anonymous"` before `src`, awaits `decode()`; draws the image into a detached `document.createElement("canvas")` at about twice the grid size (browser smoothing), reads it with `getContext("2d", { willReadFrequently: true })`, filters, and `putImageData(new ImageData(…))` on `canvas` at grid size; results memoised by `url + size + colors` (at most 200 entries, least recently used dropped). It rejects on a load or decode error, a null 2D context, or a `SecurityError` from `getImageData` (a tainted canvas), so the caller shows frame and title alone (R6); after `signal` aborts it rejects with `AbortError` and draws nothing. Steam's CDN hosts answer `access-control-allow-origin: *` (checked 2026-10-02); the README notes that a future CSP must allow them in `img-src`.
- Layout: `packages/pixel-art-filter/{package.json (name `pixel-art-filter`, private, `type: module`, `exports` and `types` → `./src/index.ts`, Vitest as devDependency), tsconfig.json (lib ES2022 + DOM, `types: []`, includes `src` and `test`), src/, test/, README.md}`. Root `package.json`: `workspaces: ["packages/*"]`, Vitest `5.0.3` devDependency, `test:js` = `vitest run`, `typecheck` = `tsc --noEmit && tsc --noEmit -p packages/pixel-art-filter`. Root `vitest.config.ts` without `RubyPlugin` (`test.include: ["packages/*/test/**/*.test.ts"]`, environment node), since the root Vite config roots Vitest in `app/frontend`. `Dockerfile` copies the package's `package.json` before `npm ci`. `config/vite.json` adds `watchAdditionalPaths: ["packages/pixel-art-filter/src/**/*"]`. CI's test job runs `npm run test:js` after the type check. The architecture's Stack table gains Vitest 5.0.3.
- Isolation test: reads the package sources with `import.meta.glob("../src/**/*.ts", { query: "?raw", import: "default", eager: true })`, fails on zero files, and asserts every import specifier is relative and stays inside the package.
- Browser-helper tests stub `Image`, `ImageData` and `document.createElement` with `vi.stubGlobal` (no DOM library).

**Never:** no Rails or app code in the package; no image stored or proxied by gameble; no dithering; no card component or ×2 display (story 3.5); no new dependency beyond Vitest.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Downscale | 4 × 4 of four 2 × 2 blocks → 2 × 2 | the four colours exactly | — |
| Uneven | 3 × 3 → 2 × 2 (crop none) | the area-weighted bytes written in the test | — |
| Cover crop | 100 × 100 → 2 × 3 | centre 66.7 × 100 region used | — |
| Upscale | 1 × 1 → 2 × 3 | every pixel that colour | — |
| Partial alpha | a pixel of alpha 100 and one of 200 | 0 (transparent) and 255 | — |
| Few colours | 5 distinct colours, 16 | palette of those 5, pixels unchanged | — |
| Weighted split | A × 3, B × 1, `colors = 2` | palette exactly A and B | — |
| One colour / `colors = 1` | single-colour image; a gradient with 1 | palette of 1 | — |
| All transparent | every pixel alpha 0 | empty palette, pixels unchanged | — |
| Many colours | synthetic 600 × 900 gradient sample → 120 × 180 | ≤ 16 colours; same palette and pixels on a second run; under 500 ms | — |
| Nearest tie | a pixel equidistant to entries 0 and 1 | entry 0 | — |
| Bad input | size 0, NaN, negative or fractional; `colors` 0 or 300; wrong data length | — | `RangeError` |
| Load error / tainted / no context | stubbed failures | promise rejects | caller falls back |
| Abort | signal aborted before the draw | rejects `AbortError`, canvas untouched | — |
| Memo | same URL and size twice | one load | — |
| Isolation | package sources | ≥ 1 file; no import outside the package | test |

</frozen-after-approval>

## Code Map

- `package.json`, `package-lock.json`, `tsconfig.json`, `vite.config.ts` -- root JavaScript setup; add root `vitest.config.ts`.
- `Dockerfile` -- the `npm ci` layer copies only `package.json` and the lockfile today.
- `config/vite.json` -- vite_ruby's autoBuild watch list.
- `.github/workflows/ci.yml` (~97–101) -- `npm ci`, `npm run typecheck` in the test job; add `npm run test:js`.
- `_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md`, Stack table.

## Tasks & Acceptance

**Execution:**
- [x] `packages/pixel-art-filter/**` -- core, browser helper, tests, README.
- [x] root `package.json`, lockfile, `vitest.config.ts`; `Dockerfile`; `config/vite.json`.
- [x] `.github/workflows/ci.yml`; architecture Stack table.

**Acceptance Criteria:**
- Given `npm run test:js`, when run, then every matrix row passes, including the isolation test.
- Given `npm run typecheck`, `bin/rails test` and `bin/rubocop`, when run, then all pass.

## Implementation Notes

- `quantize` treats alpha 0 as transparent (copied unchanged, out of the palette); any other alpha is opaque and kept. After `pixelate` alpha is binary, so the two agree.
- The median-cut boundary nearest the population median is chosen by population distance; ties go to the lower boundary. A split box is replaced in place by its two halves, which sets the palette order.
- With exactly as many or fewer unique colours than `colors`, the palette keeps the colours in first-appearance order.
- `renderArt` draws the whole image on the scratch canvas scaled to cover twice the grid (aspect kept); the core's `"cover"` crop then centres it. The memo holds the in-flight promise, so concurrent calls share one load; a rejected load leaves the memo. An abort rejects only the caller's promise, not the shared load.
- `test/import-meta.d.ts` types `import.meta.glob` for the package's `tsc` run (`types: []`).

## Plan Change Log

## Review Triage Log

### Pass 1 (quick) — high 0, medium 0, low 2, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | low | patch | The cover-crop test passed for any narrower centred crop, so the 66.7 × 100 region was not pinned | Confirmed. Red edge columns 16 and 83; exact bytes `[255, 252, 252, 255]` asserted. |
| 2 | low | patch | The isolation regex matched comments and missed `require`, `import x = require` and template-literal imports | Confirmed. Comments stripped before scanning; all forms matched; checked with temporary offending files. |


## Verification

**Commands:**
- `npm ci && npm run typecheck && npm run test:js` -- expected: green.
- `bin/rails test` -- expected: all green.
- `docker build .` is not run here (no deploy); the Dockerfile change is reviewed by reading.
