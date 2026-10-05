import { assertPixels, assertSize, type Pixels } from "./pixels"

/** `"cover"` crops the source to the target ratio; `"none"` stretches it. */
export type Crop = "cover" | "none"

/**
 * Where a `"cover"` crop sits vertically when the source is taller than the
 * target ratio: 0 keeps the top, 0.5 the middle, 1 the bottom. Covers put
 * their title and faces above the middle (AD-17).
 */
export const DEFAULT_ANCHOR = 0.42

export type PixelateOptions = { crop?: Crop; anchor?: number }

/** A rectangle of the source, in source pixels (not rounded). */
export type Region = { x: number; y: number; width: number; height: number }

/** One source index and the share of it a target pixel covers. */
type Tap = { index: number; weight: number }

/**
 * Resizes `source` to `width × height`. Each target pixel is the area-weighted
 * mean of the source pixels it covers, with RGB weighted by alpha. On an axis
 * where the source is smaller than the target, the covering pixel is used.
 * Alpha is then made binary: 128 or more becomes 255, less becomes 0 (RGB 0).
 */
export function pixelate(source: Pixels, width: number, height: number, { crop = "cover", anchor = DEFAULT_ANCHOR }: PixelateOptions = {}): Pixels {
  assertPixels(source)
  const region = cropRegion(source.width, source.height, width, height, { crop, anchor })
  const columns = taps(source.width, region.x, region.width, width)
  const rows = taps(source.height, region.y, region.height, height)

  const input = source.data
  const output = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let total = 0
      let alpha = 0
      let red = 0
      let green = 0
      let blue = 0
      for (const row of rows[y]) {
        for (const column of columns[x]) {
          const weight = row.weight * column.weight
          const offset = (row.index * source.width + column.index) * 4
          const weightedAlpha = weight * input[offset + 3]
          total += weight
          alpha += weightedAlpha
          red += weightedAlpha * input[offset]
          green += weightedAlpha * input[offset + 1]
          blue += weightedAlpha * input[offset + 2]
        }
      }
      const offset = (y * width + x) * 4
      if (Math.round(alpha / total) >= 128) {
        output[offset] = Math.round(red / alpha)
        output[offset + 1] = Math.round(green / alpha)
        output[offset + 2] = Math.round(blue / alpha)
        output[offset + 3] = 255
      }
    }
  }
  return { width, height, data: output }
}

/**
 * The part of a `sourceWidth × sourceHeight` image that a `width × height`
 * target shows. `"cover"` keeps the largest region of the target's ratio,
 * centred horizontally and placed vertically by `anchor`; `"none"` keeps the
 * whole source. Used by `pixelate` and by the browser's downscale.
 */
export function cropRegion(
  sourceWidth: number,
  sourceHeight: number,
  width: number,
  height: number,
  { crop = "cover", anchor = DEFAULT_ANCHOR }: PixelateOptions = {},
): Region {
  assertSize("source width", sourceWidth)
  assertSize("source height", sourceHeight)
  assertSize("width", width)
  assertSize("height", height)
  assertAnchor(anchor)
  if (crop === "none") return { x: 0, y: 0, width: sourceWidth, height: sourceHeight }

  const targetRatio = width / height
  if (sourceWidth / sourceHeight > targetRatio) {
    const regionWidth = sourceHeight * targetRatio
    return { x: (sourceWidth - regionWidth) / 2, y: 0, width: regionWidth, height: sourceHeight }
  }
  const regionHeight = sourceWidth / targetRatio
  return { x: 0, y: (sourceHeight - regionHeight) * anchor, width: sourceWidth, height: regionHeight }
}

function assertAnchor(anchor: number): void {
  if (!Number.isFinite(anchor) || anchor < 0 || anchor > 1) {
    throw new RangeError(`anchor must be a number from 0 to 1, got ${anchor}`)
  }
}

/** For each of `count` target cells, the source indices it covers along one axis. */
function taps(sourceLength: number, start: number, length: number, count: number): Tap[][] {
  const step = length / count
  const result: Tap[][] = []
  for (let cell = 0; cell < count; cell++) {
    const from = start + cell * step
    const to = from + step
    if (step < 1) {
      result.push([{ index: clamp(Math.floor((from + to) / 2), sourceLength), weight: 1 }])
      continue
    }
    const cellTaps: Tap[] = []
    for (let index = Math.floor(from); index < to; index++) {
      const weight = Math.min(to, index + 1) - Math.max(from, index)
      if (weight > 1e-9) cellTaps.push({ index: clamp(index, sourceLength), weight })
    }
    result.push(cellTaps)
  }
  return result
}

function clamp(index: number, length: number): number {
  return Math.min(Math.max(index, 0), length - 1)
}
