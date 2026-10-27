import { describe, expect, it } from "vitest"
import { downscale, halvingSizes, type Surface } from "./downscale"
import { FakeSurface } from "./test_fakes"
import { image } from "./test_helpers"

describe("halvingSizes", () => {
  it("halves a cover's region until it is within twice the art size", () => {
    // A 600 × 900 cover cropped to 68 × 108 keeps 566.7 × 900.
    expect(halvingSizes(900 * (68 / 108), 900, 68, 108)).toEqual([
      { width: 283, height: 450 },
      { width: 142, height: 225 },
      { width: 71, height: 113 },
    ])
  })

  it("keeps a region already within twice the art size in one step, never under the art size", () => {
    expect(halvingSizes(120, 180, 80, 120)).toEqual([{ width: 120, height: 180 }])
    expect(halvingSizes(40, 60, 80, 120)).toEqual([{ width: 80, height: 120 }])
  })
})

describe("downscale", () => {
  it("draws the crop on the first surface and each step from the one before", () => {
    const surfaces: FakeSurface[] = []
    const source = new FakeSurface(600, 900)
    source.pixels = image(600, 900, () => [10, 20, 30, 255])

    const last = downscale(source as unknown as CanvasImageSource, 600, 900, 68, 108, (width, height) => {
      const surface = new FakeSurface(width, height)
      surfaces.push(surface)
      return surface as unknown as Surface
    })

    expect(surfaces.map(({ width, height }) => [width, height])).toEqual([
      [283, 450],
      [142, 225],
      [71, 113],
    ])
    expect(surfaces[0].context.draws[0].source).toBe(source)
    expect(surfaces[1].context.draws[0]).toEqual({ source: surfaces[0], args: [0, 0, 283, 450, 0, 0, 142, 225] })
    expect(last).toMatchObject({ canvas: surfaces[2], width: 71, height: 113 })
  })

  it("answers null when a surface has no 2D context", () => {
    expect(downscale({} as CanvasImageSource, 600, 900, 68, 108, () => null)).toBeNull()
  })
})
