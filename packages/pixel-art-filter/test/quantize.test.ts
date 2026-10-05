import { describe, expect, it } from "vitest"
import { applyPalette, buildPalette, DEFAULT_COLORS, filter, quantize } from "../src/index"
import { nearest } from "../src/quantize"
import { distinctColors, fromPixels, image, toPixels, type Rgba } from "./helpers"

const A: Rgba = [200, 40, 40, 255]
const B: Rgba = [20, 60, 220, 255]

describe("quantize", () => {
  it("keeps exactly the colours of an image that has few", () => {
    const colors: Rgba[] = [[1, 2, 3, 255], [250, 0, 0, 255], [0, 250, 0, 255], [0, 0, 250, 255], [9, 9, 9, 255]]
    const source = fromPixels(3, 2, [...colors, colors[0]])

    const result = quantize(source)

    expect(result.palette).toEqual(colors.map((color) => color.slice(0, 3)))
    expect(Array.from(result.pixels.data)).toEqual(Array.from(source.data))
  })

  it("keeps both colours of a weighted pair", () => {
    const result = quantize(fromPixels(2, 2, [A, A, A, B]), 2)

    expect(result.palette).toEqual([A.slice(0, 3), B.slice(0, 3)])
  })

  it("splits a box at the population median", () => {
    const black: Rgba = [0, 0, 0, 255]
    const source = fromPixels(8, 1, [black, black, black, black, black, black, [100, 0, 0, 255], [110, 0, 0, 255]])

    const result = quantize(source, 2)

    expect(result.palette).toEqual([[0, 0, 0], [105, 0, 0]])
    expect(toPixels(result.pixels).slice(5)).toEqual([black, [105, 0, 0, 255], [105, 0, 0, 255]])
  })

  it("gives a palette of one for a single colour", () => {
    expect(quantize(image(4, 4, () => A)).palette).toEqual([A.slice(0, 3)])
  })

  it("reduces a gradient to its mean with one colour", () => {
    const source = fromPixels(4, 1, [[0, 0, 0, 255], [10, 0, 0, 255], [20, 0, 0, 255], [31, 0, 0, 255]])

    const result = quantize(source, 1)

    expect(result.palette).toEqual([[15, 0, 0]])
    expect(toPixels(result.pixels)).toEqual(Array(4).fill([15, 0, 0, 255]))
  })

  it("leaves an all-transparent image unchanged with an empty palette", () => {
    const source = image(3, 2, (x) => [x, 0, 0, 0])

    const result = quantize(source)

    expect(result.palette).toEqual([])
    expect(Array.from(result.pixels.data)).toEqual(Array.from(source.data))
  })

  it("keeps transparent pixels transparent and out of the palette", () => {
    const transparent: Rgba = [255, 255, 255, 0]

    const result = quantize(fromPixels(3, 1, [A, transparent, B]), 1)

    expect(result.palette).toHaveLength(1)
    expect(toPixels(result.pixels)[1]).toEqual(transparent)
  })

  it("maps a pixel equidistant to two entries to the first", () => {
    // Median cut gives [0, 0, 0] then [2, 0, 0]; [1, 0, 0] is as close to both.
    const source = fromPixels(3, 1, [[0, 0, 0, 255], [1, 0, 0, 255], [3, 0, 0, 255]])

    const result = quantize(source, 2)

    expect(result.palette).toEqual([[0, 0, 0], [2, 0, 0]])
    expect(toPixels(result.pixels)[1]).toEqual([0, 0, 0, 255])
    expect(nearest([[0, 0, 0], [2, 0, 0]], 1, 0, 0)).toBe(0)
  })

  it("leaves its input untouched", () => {
    const source = fromPixels(3, 1, [[0, 0, 0, 255], [1, 0, 0, 255], [3, 0, 0, 255]])
    const before = Array.from(source.data)

    quantize(source, 1)

    expect(Array.from(source.data)).toEqual(before)
  })

  it.each([0, 300, 1.5, Number.NaN, -4])("rejects %s colours", (colors) => {
    expect(() => quantize(fromPixels(1, 1, [A]), colors)).toThrow(RangeError)
  })

  it("rejects pixels of the wrong data length", () => {
    expect(() => quantize({ width: 2, height: 1, data: new Uint8ClampedArray(4) })).toThrow(RangeError)
  })
})

describe("buildPalette and applyPalette", () => {
  // 64 distinct colours, so the default of 32 has to merge them.
  const many = image(8, 8, (x, y) => [x * 32, y * 32, (x * 8 + y) * 4, 255])

  it("default to 32 colours", () => {
    expect(DEFAULT_COLORS).toBe(32)
    expect(buildPalette(many)).toHaveLength(32)
    expect(quantize(many).palette).toHaveLength(32)
  })

  it("make quantize when chained", () => {
    const palette = buildPalette(many, 8)

    expect(applyPalette(many, palette)).toEqual(quantize(many, 8).pixels)
  })

  it("remap another image to a given palette, keeping alpha and transparent pixels", () => {
    const palette = buildPalette(fromPixels(2, 1, [A, B]))
    const other = fromPixels(3, 1, [[190, 50, 30, 200], [30, 70, 200, 255], [1, 2, 3, 0]])

    expect(toPixels(applyPalette(other, palette))).toEqual([[200, 40, 40, 200], [20, 60, 220, 255], [1, 2, 3, 0]])
  })

  it("refuse an empty or oversized palette", () => {
    expect(() => applyPalette(fromPixels(1, 1, [A]), [])).toThrow(RangeError)
    expect(() => applyPalette(fromPixels(1, 1, [A]), Array(257).fill([0, 0, 0]))).toThrow(RangeError)
  })
})

describe("filter", () => {
  // A colourful 600 × 900 sample in the size of a vertical Steam image.
  const sample = image(600, 900, (x, y) => [
    (x * 255) / 599,
    (y * 255) / 899,
    ((x + y) * 7) % 256,
    255,
  ])

  it("pixelates to the grid and reduces to 32 colours, the same way every time", () => {
    const started = performance.now()
    const first = filter(sample, { width: 120, height: 180 })
    const elapsed = performance.now() - started
    const second = filter(sample, { width: 120, height: 180 })

    expect(first.pixels.width).toBe(120)
    expect(first.pixels.height).toBe(180)
    expect(first.palette.length).toBe(32)
    expect(distinctColors(first.pixels).size).toBeLessThanOrEqual(32)
    expect(second.palette).toEqual(first.palette)
    expect(Array.from(second.pixels.data)).toEqual(Array.from(first.pixels.data))
    expect(elapsed).toBeLessThan(500)
  })

  it("takes a colour count and a crop", () => {
    const result = filter(sample, { width: 20, height: 20, colors: 4, crop: "none" })

    expect(result.palette).toHaveLength(4)
    expect(distinctColors(result.pixels).size).toBeLessThanOrEqual(4)
  })

  it("rejects bad sizes and colour counts", () => {
    expect(() => filter(sample, { width: 0, height: 180 })).toThrow(RangeError)
    expect(() => filter(sample, { width: 120, height: 180, colors: 0 })).toThrow(RangeError)
    expect(() => filter(sample, { width: 120, height: 180, colors: 300 })).toThrow(RangeError)
  })
})
