# pixel-art-filter

Turns an image into pixel art: it centre-crops and downscales the image to a small grid, then reduces it to a few colours computed for that image (median cut, no dithering). It is written in TypeScript and depends on nothing.

## Core

The core works on RGBA pixels and runs anywhere.

```ts
import { filter, pixelate, quantize, type Pixels } from "pixel-art-filter"

const source: Pixels = { width, height, data } // data: Uint8ClampedArray, width × height × 4 bytes

const { palette, pixels } = filter(source, { width: 80, height: 120, colors: 16 })
```

- `pixelate(source, width, height, { crop })` resizes to `width × height`. `crop: "cover"` (the default) centre-crops the source to the target ratio; `"none"` stretches it. Each target pixel is the area-weighted mean of the source pixels it covers, with RGB weighted by alpha. Alpha is then made binary: 128 or more is opaque, less is transparent.
- `quantize(pixels, colors = 16)` returns `{ palette, pixels }`: at most `colors` colours, each pixel mapped to the nearest one. Pixels of alpha 0 stay as they are and are kept out of the palette. The same input always gives the same result.
- `filter(source, { width, height, colors, crop })` is `pixelate` followed by `quantize`.

A size that is not a positive integer, a colour count outside 1–256, or data of the wrong length throws a `RangeError`.

## Browser

```ts
import { renderArt } from "pixel-art-filter"

try {
  await renderArt(url, canvas, { width: 80, height: 120, colors: 16, signal })
} catch {
  // Show the card without art.
}
```

`renderArt` loads the image with `crossOrigin = "anonymous"`, draws it at about twice the grid size on a scratch canvas, filters it, and draws the result on `canvas` at grid size. Scale the canvas up with CSS (`image-rendering: pixelated`). Results are kept in memory by URL, size and colour count, at most 200 of them.

It rejects when the image cannot be loaded or decoded, when a canvas has no 2D context, or when the image taints the canvas because its host does not allow cross-origin reads. After `signal` aborts, it rejects with an `AbortError` and draws nothing.

Images must come from a host that sends `Access-Control-Allow-Origin`. Steam's CDN hosts answer `access-control-allow-origin: *` (checked 2026-10-02). A Content Security Policy must list those hosts in `img-src`.

## Tests

From the repository root:

```sh
npm run test:js
npm run typecheck
```
