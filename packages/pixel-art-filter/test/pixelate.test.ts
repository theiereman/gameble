import { describe, expect, it } from "vitest"
import { pixelate } from "../src/index"
import { fromPixels, image, toPixels, type Rgba } from "./helpers"

const RED: Rgba = [255, 0, 0, 255]
const GREEN: Rgba = [0, 255, 0, 255]
const BLUE: Rgba = [0, 0, 255, 255]
const WHITE: Rgba = [255, 255, 255, 255]
const BLACK: Rgba = [0, 0, 0, 255]

describe("pixelate", () => {
  it("downscales four 2 × 2 blocks to their four colours exactly", () => {
    const blocks = [RED, GREEN, BLUE, WHITE]
    const source = image(4, 4, (x, y) => blocks[Math.floor(y / 2) * 2 + Math.floor(x / 2)])

    expect(toPixels(pixelate(source, 2, 2))).toEqual(blocks)
  })

  it("weights uneven cells by the area they cover", () => {
    const values = [0, 30, 60, 90, 120, 150, 180, 210, 240]
    const source = fromPixels(3, 3, values.map((value): Rgba => [value, value, value, 255]))

    const result = pixelate(source, 2, 2, { crop: "none" })

    expect(Array.from(result.data)).toEqual([
      40, 40, 40, 255, 80, 80, 80, 255,
      160, 160, 160, 255, 200, 200, 200, 255,
    ])
  })

  it("weights colour by alpha", () => {
    const source = fromPixels(1, 2, [[255, 0, 0, 255], [0, 0, 255, 128]])

    // Alpha mean 191.5 rounds to 192: opaque. RGB is premultiplied by alpha.
    expect(toPixels(pixelate(source, 1, 1, { crop: "none" }))).toEqual([[170, 0, 85, 255]])
  })

  it("crops the centre of the source to the target ratio", () => {
    // The centre 66.7 × 100 region spans x = 16.7 to 83.3: it takes a third of
    // the red edge columns 16 and 83, all of the white 17 to 82, none of the black.
    const source = image(100, 100, (x) => (x === 16 || x === 83 ? RED : x > 16 && x < 83 ? WHITE : BLACK))

    // Each cell: 1/3 of red and 33 of white, so G and B are 255 × 33 / 33.33 = 252.
    expect(toPixels(pixelate(source, 2, 3))).toEqual(Array(6).fill([255, 252, 252, 255]))
    expect(toPixels(pixelate(source, 2, 3, { crop: "none" }))).not.toEqual(Array(6).fill([255, 252, 252, 255]))
  })

  it("crops the centre vertically when the source is taller than the target", () => {
    const source = image(10, 40, (_x, y) => (y >= 10 && y < 30 ? GREEN : BLACK))

    expect(toPixels(pixelate(source, 2, 4))).toEqual(Array(8).fill(GREEN))
  })

  it("repeats the covering pixel when the source is smaller than the target", () => {
    expect(toPixels(pixelate(fromPixels(1, 1, [BLUE]), 2, 3))).toEqual(Array(6).fill(BLUE))
    expect(toPixels(pixelate(fromPixels(2, 1, [RED, GREEN]), 4, 2, { crop: "none" }))).toEqual([
      RED, RED, GREEN, GREEN,
      RED, RED, GREEN, GREEN,
    ])
  })

  it("makes alpha binary", () => {
    const source = fromPixels(2, 1, [[10, 20, 30, 100], [40, 50, 60, 200]])

    expect(toPixels(pixelate(source, 2, 1))).toEqual([[0, 0, 0, 0], [40, 50, 60, 255]])
  })

  it("leaves the source untouched", () => {
    const source = fromPixels(2, 1, [[10, 20, 30, 100], [40, 50, 60, 200]])
    const before = Array.from(source.data)

    pixelate(source, 1, 1)

    expect(Array.from(source.data)).toEqual(before)
  })

  it.each([0, -1, 1.5, Number.NaN, Number.POSITIVE_INFINITY])("rejects a target size of %s", (size) => {
    const source = fromPixels(1, 1, [RED])

    expect(() => pixelate(source, size, 1)).toThrow(RangeError)
    expect(() => pixelate(source, 1, size)).toThrow(RangeError)
  })

  it("rejects a source of bad size or data length", () => {
    expect(() => pixelate({ width: 0, height: 1, data: new Uint8ClampedArray(0) }, 1, 1)).toThrow(RangeError)
    expect(() => pixelate({ width: 2.5, height: 1, data: new Uint8ClampedArray(10) }, 1, 1)).toThrow(RangeError)
    expect(() => pixelate({ width: 2, height: 2, data: new Uint8ClampedArray(15) }, 1, 1)).toThrow(RangeError)
  })
})
