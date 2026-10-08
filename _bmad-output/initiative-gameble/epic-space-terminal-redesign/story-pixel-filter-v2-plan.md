---
title: 'Pixel filter v2'
type: 'feature'
ticket: '5'
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
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** `packages/pixel-art-filter` filters covers on the main thread (16 colours, centre crop, one palette per size, failures retried but CORS refusal = missing art, no placeholder detection), which blocks animations, gives inconsistent colours across sizes and silently shows Steam's grey 300 × 450 placeholder (feasibility H1, M3, C1, L1, L6).

**Approach:** Rewrite the package and its client to AD-17: the work moves into a lazily started module Web Worker using `OffscreenCanvas` (crop anchored at 42 %, halving downscale to one image pixel per art pixel, 32 colours by median cut, no dithering), with one palette per game computed at the largest art size and reused at every size, a bounded main-thread cache of `ImageBitmap`s closed on eviction, a main-thread "pixelated without palette" path for CORS failures and for browsers lacking the APIs, and placeholder detection. The current card face (small/large) keeps working through `app/frontend/lib/card_art.ts`.

## Boundaries & Constraints

**Always:**
- All work happens in the worktree `/home/teyermann/projets/gameble/.claude/worktrees/agent-adfe1338108721fe3`; never touch `/home/teyermann/projets/gameble` itself. Rails tests use `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w85` (already created and loaded).
- The package imports nothing outside itself (`test/isolation.test.ts` must keep passing) and stays TypeScript, no runtime dependency.
- Image requests: no added header, `referrerPolicy: "no-referrer"`, `credentials: "omit"`; nothing stored (no service worker, Cache Storage, IndexedDB, localStorage); nothing image-derived sent to the server.
- A failure (missing, decode error, CORS-then-plain failure) is never cached: the next render tries again.
- Evicted or disposed bitmaps are `close()`d. The worker is created only on the first render.
- `data-art` on the art container: `drawn` (worker, palette), `plain` (main-thread fallback, no palette), `failed` (missing; canvas hidden). Abort leaves both untouched.
- `CardComponent`, `Card.tsx`, their markup and the small/large art sizes (68 × 108, 104 × 164) stay as they are; existing tests keep passing.

**Never:** no redesign of the card face (story 8.6), no new card sizes, no CSP change (story 8.4), no server-side palette, no service worker, no dithering, no worker pool beyond one worker.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Happy path | CORS-readable colour cover ≥ 300 × 450 | canvas at art size, ≤ 32 colours, crop anchored 42 % from top, `data-art=drawn` | — |
| Palette reuse | same URL at small then large (any order) | worker computes the palette once, at the palette size; both sizes use only its colours | — |
| Placeholder size | decoded image under 300 wide or 450 high | `failed` | not cached |
| Placeholder grey | every pixel R≈G≈B (within 2) | `failed` | not cached |
| Missing | HTTP error / undecodable | `failed`; no main-thread retry | not cached; next mount retries |
| CORS failure | worker `fetch` rejects (TypeError) | one main-thread retry with a plain `Image` (no `crossOrigin`, no referrer), crop + halving to art size, no palette, `data-art=plain` | plain load fails or is too small → `failed` |
| Old browser | no `Worker`, `OffscreenCanvas` or `createImageBitmap`; or worker reports no 2D `OffscreenCanvas` context; or worker fails to load | main-thread plain path for this and later renders | as CORS failure |
| Concurrency | 30 renders at once | at most `concurrency` (2–4, default 3) jobs in the worker at once; the rest queued | — |
| Abort | signal aborts while queued / in flight | rejects `AbortError`, draws nothing; a queued job no caller waits for is dropped; an in-flight one finishes into the cache | — |
| Cache bound | more than `cacheLimit` (default 120) distinct url+size results | least recently used evicted and `close()`d; same url+size served from cache without a job | — |

</intent-contract>

## Code Map

- `packages/pixel-art-filter/src/pixelate.ts` -- area-weighted resize, `crop: cover|none`; add vertical anchor (fraction, AD-17 default 0.42) and export the crop-region computation for the browser downscale.
- `packages/pixel-art-filter/src/quantize.ts` -- median cut + `nearest`; split into palette computation and remap-to-given-palette, default 32 colours; keep determinism.
- `packages/pixel-art-filter/src/filter.ts`, `src/pixels.ts`, `src/index.ts` -- core API; keep the `RangeError` validation style.
- `packages/pixel-art-filter/src/render-art.ts` -- the old main-thread loader (crossOrigin image, memo of 200 promises); replace with the worker job, the main-thread renderer and the plain fallback. Its `abortable` / `abortError` helpers are reusable.
- `packages/pixel-art-filter/test/*.test.ts` -- vitest, node environment, fakes stubbed with `vi.stubGlobal` (see `render-art.test.ts` for the style); `helpers.ts` builds `Pixels`.
- `packages/pixel-art-filter/README.md` -- rewrite for the new API.
- `app/frontend/lib/card_art.ts` -- `CARD_ART`, `drawCardArt` (used by `controllers/card_art_controller.ts` and `components/Card.tsx`); derive the palette size from the largest `CARD_ART` entry, set `data-art` from the render result.
- `app/frontend/controllers/card_art_controller.ts` -- lazy via `IntersectionObserver`; keep, adjust comments only if needed.
- `vite.config.ts` -- add `worker: { format: "es" }` so `new Worker(new URL("./worker.ts", import.meta.url), { type: "module" })` in the package is bundled.
- `test/system/card_preview_test.rb` -- existing art assertions (`drawn` 16, `failed` for the emerald 404, canvas pixels readable); the back-office preview (admin sign-in in its `setup`) is the host page for new system tests. Sample art: `app/frontend/images/card_preview/sample.png` (300 × 450, colour).
- Test server: Capybara serves on `127.0.0.1:<port>` and public files carry no `Access-Control-Allow-Origin`, so the same file at `http://localhost:<port>/...` is a real CORS failure.

## Tasks & Acceptance

**Execution:**
- [x] `packages/pixel-art-filter/src/pixelate.ts`, `quantize.ts`, `filter.ts`, new `placeholder.ts` -- crop anchor, palette/remap split (32 default), `isPlaceholder` (size under 300 × 450, or single channel within 2) -- pure, testable core.
- [x] `packages/pixel-art-filter/src/worker-job.ts` (new) -- one job with injected `fetch`, `createImageBitmap`, canvas factory and a bounded palette cache (≈256 games): fetch (cors, no-referrer, omit credentials), decode, size check, crop region, halving steps on `OffscreenCanvas` to within 2× target, exact `pixelate` to art size, grey check, palette at palette size (cached per URL, computed once), remap, `transferToImageBitmap`; result `drawn | missing | cors | unsupported`.
- [x] `packages/pixel-art-filter/src/worker.ts` (new) -- worker entry wiring messages to `worker-job`, transferring the bitmap.
- [x] `packages/pixel-art-filter/src/renderer.ts` (new, replaces `render-art.ts`) -- `createArtRenderer({ concurrency, cacheLimit, createWorker, supported })` and a lazily created default `renderArt(url, canvas, { width, height, paletteWidth, paletteHeight, colors, signal })` resolving `"drawn" | "plain"`, rejecting a typed missing error or `AbortError`; queue, dedupe, LRU bitmap cache, fallbacks; draws with a 2D context `drawImage`.
- [x] `packages/pixel-art-filter/src/plain.ts` (new) -- main-thread plain path: `Image` without `crossOrigin`, `referrerPolicy = "no-referrer"`, size check, crop anchored 42 %, halving with canvases, draw to target.
- [x] `packages/pixel-art-filter/test/` -- replace `render-art.test.ts`; cover quantisation (32), anchor crop, palette reuse across sizes, placeholder (size and grey), CORS fallback, old-browser fallback, concurrency cap, abort, LRU eviction closing bitmaps, failure not cached, no added headers / no-referrer.
- [x] `app/frontend/lib/card_art.ts` -- new API, palette size from the largest size, `data-art` from result.
- [x] `vite.config.ts` -- `worker.format: "es"`.
- [x] `test/system/card_art_test.rb` (new) -- host page: back-office preview as admin; inject card-art elements via JS.
- [x] `packages/pixel-art-filter/README.md` -- document the API, fallbacks and placeholder rule.

**Acceptance Criteria:**
- Given 30 card-art elements with distinct URLs of the sample cover on one page, when they render, then all 30 reach `data-art=drawn`, each canvas has at most 32 distinct opaque colours, and the window's `performance` resource entries include none of those URLs (the worker fetched them).
- Given a grey 300 × 450 image (generated in the page as a data URL), when rendered, then the container shows `data-art=failed` with the canvas hidden.
- Given the sample cover requested cross-origin (`localhost` instead of `127.0.0.1`) without CORS headers, when rendered, then `data-art=plain` and the canvas is shown.
- Given the existing suites, when run, then `card_preview_test`, `pack_reveal_test` and `tome_test` pass unchanged.

## Implementation Notes

- Two helper modules beyond the plan's list: `src/downscale.ts` (`halvingSizes`, `downscale`: crop + halving shared by the worker job and the plain path) and `src/errors.ts` (`ArtMissingError`, `abortable`, `abortError`, taken from the old `render-art.ts`). `test/fakes.ts` fakes `OffscreenCanvas`/`ImageBitmap` with nearest sampling.
- `pixelate`'s default anchor is now 0.42 (`DEFAULT_ANCHOR`); the old "centre vertically" unit test passes `anchor: 0.5`. `quantize`/`filter` default to 32 colours; `buildPalette` + `applyPalette` are the split.
- The worker answers `cors` for any `fetch` rejection, so an unreachable host (the `images.example.test` fixtures) goes through the plain retry and ends `failed`, as before. A job's unexpected exception answers `missing`.
- The palette cache is keyed by URL; an entry computed for another colour count is recomputed. Halving stops once both sides are within 2× the art size, then `pixelate(..., { crop: "none" })` averages exactly.
- `createArtRenderer` also takes a `plain` renderer (injected in tests). `dispose()` aborts waiting renders with `AbortError`.

## Plan Change Log

## Review Triage Log

### 2026-10-05 — Review pass
- verdicts: 5 findings — high 0, medium 1, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` Two sizes of one game in the worker at once each fetch, decode and run median cut (palette checked only after the awaited fetch), so "palette computed once" did not hold — `createJobRunner` in `worker-job.ts` chains jobs per URL and `worker.ts` uses it; unit test runs two sizes concurrently and sees one palette computation.
  - `[low]` `[patch]` The grey check ran on the art at the job's size, so one URL could be `failed` at one size and `drawn` at another — the check now runs once on the palette-size pixels when the palette is first computed; a cached palette means the image passed; tests added.
  - `[low]` `[patch]` The plain (no-CORS) image request cannot omit credentials, unlike the plan's rule — unavoidable for a no-CORS image (a CORS request is the very thing that failed); the README fallback section now states it.
  - `[medium]` `[patch]` Worker `fetch` had no timeout, so hung connections could hold all concurrency slots and stop every later render on the page — 20 s timeout (`FETCH_TIMEOUT_MS`) over fetch and body read, answering `missing`; tests for a hung fetch and a hung body. The `messageerror` sub-point is rejected: the worker only posts plain objects and transferred `ImageBitmap`s, which cannot fail to deserialise in the same agent cluster.
  - `[false]` `[reject]` No agent instruction files to check against — not a defect: the repository has no `AGENTS.md`/`CLAUDE.md`; informational only.

## Design Notes

Palette size: the client passes the largest art size it draws (today `CARD_ART.large`, 104 × 164; story 8.6 changes the sizes, not the mechanism). The worker keys palettes by URL only, because one URL is one game. The bitmap cache key is `url|w×h|colors|pw×ph`. Draw on the target with `getContext("2d").drawImage(bitmap, 0, 0)` (not `bitmaprenderer`, which would consume the cached bitmap; the system test also reads pixels through a 2D context). Plain results are not cached.

## Verification

**Commands** (from the worktree, with the `DATABASE_URL` above exported; use `/usr/bin/git` for git):
- `npm run typecheck` -- expected: no error
- `npm run test:js` -- expected: all pass
- `bin/rubocop` -- expected: no offence
- `bundle exec packwerk validate && bundle exec packwerk check` -- expected: no violation
- `bundle exec i18n-tasks missing` -- expected: none
- `bin/rails test` -- expected: all pass
- `bin/rails test:system` -- expected: all pass

## Auto Run Result

- **Summary:** `packages/pixel-art-filter` rewritten to AD-17. Covers are fetched, cropped (anchored at 42 %), halved and averaged to one image pixel per art pixel, and reduced to 32 colours by median cut without dithering. This runs in a lazily started module Web Worker on `OffscreenCanvas`, with at most 3 jobs at once (2–4 allowed). Each game gets one palette, computed at the largest art size and reused at every size, with jobs serialised per URL. A bounded LRU of 120 `ImageBitmap`s closes the bitmaps it evicts. A CORS failure, or a browser without the APIs, falls back to a main-thread plain image pixelated without palette. A decoded image under 300 × 450 or grey everywhere counts as missing. Failures are never cached, and the fetch times out after 20 s. `app/frontend/lib/card_art.ts` drives it for the current small/large card faces, marking `data-art` as `drawn`, `plain` or `failed`.
- **Files:**
  - `packages/pixel-art-filter/src/{pixelate,quantize,filter,index}.ts`: crop anchor and `cropRegion`; `buildPalette`/`applyPalette`, 32 colours by default.
  - `src/placeholder.ts`: the size and grey rules.
  - `src/downscale.ts`: crop and halving steps.
  - `src/worker-job.ts`: job, palette cache and per-URL runner.
  - `src/worker.ts`: worker entry.
  - `src/renderer.ts`: queue, cache, fallbacks and `renderArt`.
  - `src/plain.ts`: main-thread fallback.
  - `src/errors.ts`.
  - `render-art.ts` and its test removed.
  - `packages/pixel-art-filter/test/*`: new and updated unit tests (111 JS tests in total).
  - `packages/pixel-art-filter/README.md`: rewritten.
  - `app/frontend/lib/card_art.ts`: the new client.
  - `vite.config.ts`: `worker.format: "es"`.
  - `test/system/card_art_test.rb`: 30 covers drawn by the worker, the grey placeholder missing, the CORS fallback `plain`.
- **Review:** quick lens, 5 findings. 4 patched (1 medium, 3 low), 0 deferred, and 1 rejected as false: no agent instruction files exist, so the finding is informational. The `messageerror` sub-point was rejected with its reason in the triage log.
- **Follow-up review:** `false`. One medium and no high were patched.
- **Verification (after the patches):**
  - `npm run typecheck`: clean.
  - `npm run test:js`: 111 passed.
  - `bin/rubocop`: no offences.
  - packwerk validate and check: clean.
  - `i18n-tasks missing`: none.
  - `bin/rails test`: 1014 runs, 0 failures.
  - `bin/rails test:system` with `CHROME_BIN=/usr/bin/chromium`: 49 runs, 0 failures.
- **Residual risks:**
  - The CSP of story 8.4 must allow the worker (`worker-src 'self'`) and the Steam hosts in `connect-src`, since the worker's `fetch` counts as connect. Otherwise every cover takes the plain fallback; this is recorded in `deferred-work.md`.
  - The system test that checks covers are fetched off the main thread relies on the window's resource-timing buffer (default 250 entries).
  - Any `fetch` rejection other than the timeout is treated as a CORS refusal, so an unreachable host gets one main-thread retry.
