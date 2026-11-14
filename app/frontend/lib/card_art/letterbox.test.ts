import { describe, expect, it } from "vitest"
import { findSharpBand } from "./letterbox"
import { image, type Rgba } from "./test_helpers"

const WIDTH = 96
const HEIGHT = 144

function sharp(x: number, y: number): Rgba {
  const value = 40 + ((x * 37 + y * 91 + x * y * 13) % 170)
  return [value, 255 - value, (value * 3) % 256, 255]
}

function blurred(x: number, y: number): Rgba {
  const value = 120 + Math.round(25 * Math.sin(x / 14)) + Math.round(y / 12)
  return [value, value - 30, 40, 255]
}

function letterboxed(from: number, to: number) {
  return image(WIDTH, HEIGHT, (x, y) => (y >= from && y < to ? sharp(x, y) : blurred(x, y)))
}

describe("findSharpBand", () => {
  it("finds a band in the middle, trimmed by the row that straddles its end", () => {
    const band = findSharpBand(letterboxed(40, 80))!
    expect(band.start).toBeCloseTo(40 / HEIGHT)
    expect(band.end).toBeCloseTo(79 / HEIGHT)
  })

  it("finds a band at the top and at the bottom", () => {
    const top = findSharpBand(letterboxed(0, 50))!
    expect(top.start).toBeLessThan(0.02)
    expect(top.end).toBeCloseTo(49 / HEIGHT)
    const bottom = findSharpBand(letterboxed(94, HEIGHT))!
    expect(bottom.start).toBeCloseTo(94 / HEIGHT)
    expect(bottom.end).toBeGreaterThan(0.98)
  })

  it("leaves a real portrait alone", () => {
    expect(findSharpBand(image(WIDTH, HEIGHT, sharp))).toBeNull()
  })

  it("leaves a portrait with a flat dark area alone", () => {
    expect(findSharpBand(image(WIDTH, HEIGHT, (x, y) => (y < 24 ? [8, 8, 8, 255] : sharp(x, y))))).toBeNull()
    expect(findSharpBand(image(WIDTH, HEIGHT, (x, y) => (y > 120 ? [8, 8, 8, 255] : sharp(x, y))))).toBeNull()
  })

  it("leaves a dark portrait alone", () => {
    const dark = (x: number, y: number): Rgba => [sharp(x, y)[0] / 12, 4, 6, 255]
    expect(findSharpBand(image(WIDTH, HEIGHT, dark))).toBeNull()
  })

  it("leaves a flat image alone", () => {
    expect(findSharpBand(image(WIDTH, HEIGHT, () => [90, 90, 90, 255]))).toBeNull()
  })

  it("leaves a band that is too thin or too thick for a banner alone", () => {
    expect(findSharpBand(letterboxed(60, 70))).toBeNull()
    expect(findSharpBand(letterboxed(8, 136))).toBeNull()
  })

  it("leaves a logo band on a plain cover alone, as it is too thin for a banner", () => {
    const logo = (x: number, y: number): Rgba =>
      y >= 30 && y < 62 && x % 32 < 24 ? [250, 250, 250, 255] : [10, 14, 30, 255]
    expect(findSharpBand(image(WIDTH, HEIGHT, logo))).toBeNull()
    expect(findSharpBand(letterboxed(40, 72))).toBeNull()
  })

  it("leaves a band with little padding alone", () => {
    expect(findSharpBand(letterboxed(10, 120))).toBeNull()
  })

  it("keeps a band whose artwork has a short flat stretch inside it", () => {
    const pixels = image(WIDTH, HEIGHT, (x, y) => {
      if (y >= 40 && y < 82) return y >= 58 && y < 60 ? [30, 30, 30, 255] : sharp(x, y)
      return blurred(x, y)
    })
    const band = findSharpBand(pixels)!
    expect(band.start).toBeCloseTo(40 / HEIGHT)
    expect(band.end).toBeCloseTo(81 / HEIGHT)
  })

  it("answers null for a tiny image", () => {
    expect(findSharpBand(image(8, 12, sharp))).toBeNull()
    expect(findSharpBand(image(1, 100, sharp))).toBeNull()
  })
})
