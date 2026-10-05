import { assertColors, assertPixels, type Color, type Pixels } from "./pixels"

export type Quantized = { palette: Color[]; pixels: Pixels }

/** The colour count of the card art (AD-17). */
export const DEFAULT_COLORS = 32

/** A unique colour and how many pixels have it. */
type Entry = { channels: Color; count: number }

type Box = { entries: Entry[]; population: number; ranges: Color }

/**
 * Reduces `pixels` to at most `colors` colours by median cut, without dithering:
 * `buildPalette` followed by `applyPalette`. The result depends only on the input.
 */
export function quantize(pixels: Pixels, colors = DEFAULT_COLORS): Quantized {
  const palette = buildPalette(pixels, colors)
  return { palette, pixels: { width: pixels.width, height: pixels.height, data: remap(pixels.data, palette) } }
}

/**
 * At most `colors` colours that represent `pixels`, by median cut. Pixels of
 * alpha 0 are kept out of it; an image with no other pixel gives an empty
 * palette. The result depends only on the input.
 */
export function buildPalette(pixels: Pixels, colors = DEFAULT_COLORS): Color[] {
  assertPixels(pixels)
  assertColors(colors)

  const entries = histogram(pixels.data)
  return entries.length <= colors
    ? entries.map((entry) => [...entry.channels] as Color)
    : medianCut(entries, colors).map(mean)
}

/**
 * `pixels` with every pixel that is not fully transparent taking the nearest
 * colour of `palette` (and keeping its alpha); pixels of alpha 0 are copied
 * unchanged. Used to draw every size of an image with the palette computed once.
 */
export function applyPalette(pixels: Pixels, palette: Color[]): Pixels {
  assertPixels(pixels)
  if (palette.length < 1 || palette.length > 256) {
    throw new RangeError(`palette must hold 1 to 256 colours, got ${palette.length}`)
  }
  return { width: pixels.width, height: pixels.height, data: remap(pixels.data, palette) }
}

function histogram(data: Uint8ClampedArray): Entry[] {
  const entries = new Map<number, Entry>()
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] === 0) continue
    const key = (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2]
    const entry = entries.get(key)
    if (entry) {
      entry.count++
    } else {
      entries.set(key, { channels: [data[offset], data[offset + 1], data[offset + 2]], count: 1 })
    }
  }
  return [...entries.values()]
}

function medianCut(entries: Entry[], colors: number): Box[] {
  const boxes = [box(entries)]
  while (boxes.length < colors) {
    let chosen = -1
    let chosenScore = 0
    boxes.forEach((candidate, index) => {
      const score = Math.max(...candidate.ranges) * candidate.population
      if (score > chosenScore) {
        chosen = index
        chosenScore = score
      }
    })
    if (chosen === -1) break
    boxes.splice(chosen, 1, ...split(boxes[chosen]))
  }
  return boxes
}

function box(entries: Entry[]): Box {
  const min: Color = [255, 255, 255]
  const max: Color = [0, 0, 0]
  let population = 0
  for (const { channels, count } of entries) {
    for (let channel = 0; channel < 3; channel++) {
      min[channel] = Math.min(min[channel], channels[channel])
      max[channel] = Math.max(max[channel], channels[channel])
    }
    population += count
  }
  return { entries, population, ranges: [max[0] - min[0], max[1] - min[1], max[2] - min[2]] }
}

/** Splits a box of non-zero range along its widest channel, near its population median. */
function split({ entries, population, ranges }: Box): [Box, Box] {
  const channel = ranges.indexOf(Math.max(...ranges))
  const order = [channel, ...[0, 1, 2].filter((other) => other !== channel)]
  const sorted = [...entries].sort((a, b) => {
    for (const key of order) {
      const difference = a.channels[key] - b.channels[key]
      if (difference !== 0) return difference
    }
    return 0
  })

  const half = population / 2
  let best = -1
  let bestDistance = Infinity
  let before = sorted[0].count
  for (let index = 1; index < sorted.length; index++) {
    if (sorted[index].channels[channel] !== sorted[index - 1].channels[channel]) {
      const distance = Math.abs(before - half)
      if (distance < bestDistance) {
        best = index
        bestDistance = distance
      }
    }
    before += sorted[index].count
  }
  return [box(sorted.slice(0, best)), box(sorted.slice(best))]
}

function mean({ entries, population }: Box): Color {
  const sums = [0, 0, 0]
  for (const { channels, count } of entries) {
    for (let channel = 0; channel < 3; channel++) sums[channel] += channels[channel] * count
  }
  return [Math.round(sums[0] / population), Math.round(sums[1] / population), Math.round(sums[2] / population)]
}

function remap(data: Uint8ClampedArray, palette: Color[]): Uint8ClampedArray<ArrayBuffer> {
  const output = new Uint8ClampedArray(data)
  const nearestByKey = new Map<number, number>()
  for (let offset = 0; offset < output.length; offset += 4) {
    if (output[offset + 3] === 0) continue
    const key = (output[offset] << 16) | (output[offset + 1] << 8) | output[offset + 2]
    let index = nearestByKey.get(key)
    if (index === undefined) {
      index = nearest(palette, output[offset], output[offset + 1], output[offset + 2])
      nearestByKey.set(key, index)
    }
    output[offset] = palette[index][0]
    output[offset + 1] = palette[index][1]
    output[offset + 2] = palette[index][2]
  }
  return output
}

/** The index of the palette colour closest to an RGB value; ties go to the lowest index. */
export function nearest(palette: Color[], red: number, green: number, blue: number): number {
  let best = 0
  let bestDistance = Infinity
  palette.forEach(([r, g, b], index) => {
    const distance = (r - red) ** 2 + (g - green) ** 2 + (b - blue) ** 2
    if (distance < bestDistance) {
      best = index
      bestDistance = distance
    }
  })
  return best
}
