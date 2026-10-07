# pixel-art-filter

Turns an image into pixel art: it crops the image to the art's ratio, downscales it to a small grid, then reduces it to a few colours computed for that image (median cut, no dithering). In the browser the work runs in a Web Worker on `OffscreenCanvas`. It is written in TypeScript and depends on nothing.

## Install

```sh
npm install pixel-art-filter
```

It is an ES module with type declarations, for the browser and for any JavaScript runtime that has typed arrays (the core). The browser part needs `Worker`, `OffscreenCanvas` and `createImageBitmap`; it falls back to the main thread without them (see "Fallbacks and failures").

It was written for game cover art, and its defaults come from there: a 32-colour palette, a crop anchored at 42 % from the top, and a "missing image" rule sized for Steam's grey 300 × 450 placeholder (see "Placeholders"). The core functions take all of these as options.

## Core

The core works on RGBA pixels and runs anywhere.

```ts
import { applyPalette, buildPalette, filter, pixelate, quantize, type Pixels } from "pixel-art-filter"

const source: Pixels = { width, height, data } // data: Uint8ClampedArray, width × height × 4 bytes

const { palette, pixels } = filter(source, { width: 104, height: 164 }) // 32 colours
```

- `pixelate(source, width, height, { crop, anchor })` resizes to `width × height`. `crop: "cover"` (the default) keeps the largest region of the target's ratio, centred horizontally and placed vertically by `anchor`: 0 keeps the top, 0.5 the middle, 1 the bottom; the default, `DEFAULT_ANCHOR`, is 0.42. `"none"` stretches the whole source. Each target pixel is the area-weighted mean of the source pixels it covers, with RGB weighted by alpha. Alpha is then made binary: 128 or more is opaque, less is transparent.
- `cropRegion(sourceWidth, sourceHeight, width, height, { crop, anchor })` returns that region, `{ x, y, width, height }` in source pixels.
- `buildPalette(pixels, colors = 32)` returns at most `colors` colours by median cut. Pixels of alpha 0 are kept out of it.
- `applyPalette(pixels, palette)` maps every pixel that is not fully transparent to the nearest palette colour, keeping its alpha. Use it to draw several sizes of one image with the same colours.
- `quantize(pixels, colors = 32)` is `buildPalette` then `applyPalette`, and returns `{ palette, pixels }`.
- `filter(source, { width, height, colors, crop, anchor })` is `pixelate` followed by `quantize`.

The same input always gives the same result. A size that is not a positive integer, a colour count outside 1–256, a palette outside 1–256 colours, an anchor outside 0–1, or data of the wrong length throws a `RangeError`.

### Placeholders

Steam answers a missing cover with a grey 300 × 450 placeholder. An image counts as missing when it is under 300 × 450 (`isTooSmall(width, height)`, `MIN_SOURCE`) or when it has a single channel: every pixel that is not fully transparent has R, G and B within 2 of each other (`isSingleChannel(pixels)`). `isPlaceholder(pixels)` is either.

## Browser

```ts
import { ArtMissingError, renderArt } from "pixel-art-filter"

try {
  const result = await renderArt(url, canvas, {
    width: 68, height: 108,                 // the art size, in art pixels
    paletteWidth: 104, paletteHeight: 164,  // the largest art size drawn
    colors: 32,
    signal,
  })
  // result: "drawn" (filtered, with the game's palette) or "plain" (no palette)
} catch (error) {
  // ArtMissingError: show the card without art. AbortError: do nothing.
}
```

`renderArt` draws on `canvas` at the art size; scale it up with CSS (`image-rendering: pixelated`). It uses a renderer shared by the page; `createArtRenderer({ concurrency, cacheLimit })` makes another, with `render(url, canvas, options)` and `dispose()`.

### In the worker

The worker is a module worker, created on the first render. For each job it:

1. fetches the image with `mode: "cors"`, `credentials: "omit"` and `referrerPolicy: "no-referrer"`, and no added header; a request whose response and body take more than 20 seconds (`FETCH_TIMEOUT_MS`) counts as missing;
2. decodes it with `createImageBitmap`, and counts it as missing under 300 × 450;
3. crops it anchored at 42 %, halves it on `OffscreenCanvas` until it is within twice the art size, then averages it exactly to the art size (one image pixel per art pixel);
4. remaps it to the game's palette and returns an `ImageBitmap`.

A game's palette is computed once, at the palette size, and reused at every size, so a card shows the same colours small and large. The single-channel check runs then, on the pixels at the palette size, so a game is missing at every size or at none. The worker runs one job per URL at a time, so a game's second size finds its palette, and keeps the palettes of about 256 games, keyed by URL.

On the main thread, at most `concurrency` jobs (2 to 4, default 3) are in the worker at once; the others wait in order. Renders of the same URL, size, colour count and palette size share one job. The resulting bitmaps are kept in memory, at most `cacheLimit` (default 120), and drawn with a 2D context's `drawImage`; the least recently used is closed when evicted. `dispose()` closes them all and stops the worker.

After `signal` aborts, the render rejects with an `AbortError` and draws nothing. A queued job no render waits for any more is dropped; a job already in the worker finishes into the cache.

### Fallbacks and failures

- **Missing:** an HTTP error, an undecodable image or a placeholder rejects with `ArtMissingError`. There is no retry on the main thread.
- **CORS refused** (the worker's `fetch` fails, as it does for a host that sends no `Access-Control-Allow-Origin`, or an unreachable one): the render is retried once on the main thread with a plain `Image`, without `crossOrigin` and with no referrer, cropped and halved to the art size on canvases, and drawn without palette (`"plain"`). Its pixels cannot be read, so only the size check applies. If that load fails too, it rejects with `ArtMissingError`. Unlike the worker's request, this one cannot omit credentials: a plain image request without `crossOrigin` sends the browser's cookies for the image host, if it has any.
- **Older browsers:** without `Worker`, `OffscreenCanvas` or `createImageBitmap`, when the worker has no 2D `OffscreenCanvas` context, or when the worker fails to load, this render and every later one take the main-thread path above.

A failure is never cached: the next render tries again. Images are not stored anywhere (no service worker, Cache Storage, IndexedDB or local storage) and nothing derived from them leaves the browser.

### Bundling and hosting

The worker is started with `new Worker(new URL("./worker.js", import.meta.url), { type: "module" })` (`worker.ts` in the source); a bundler that understands this pattern (Vite, webpack 5, Rollup with a plugin) bundles it, and with Vite you set `worker: { format: "es" }`. A Content Security Policy must allow the worker (`worker-src 'self'`) and list the image hosts in `connect-src` (the worker's `fetch`) and `img-src` (the main-thread fallback). Steam's CDN hosts answer `access-control-allow-origin: *` (checked 2026-10-02).

## Tests

From the repository root:

```sh
npm run test:js
npm run typecheck
```

## Publishing

The package in the repository is private and consumed from its sources. `npm run build` compiles it into `dist/` (JavaScript, `.d.ts`, a `package.json` made for npm, the README and the LICENSE), and `dist/` is what you publish:

```sh
cd packages/pixel-art-filter
npm run build
npm pack --dry-run ./dist   # lists what would be published
npm publish ./dist
```

Bump `version` in `package.json` first. Add a `repository` field to it when the code lives in a public repository.
