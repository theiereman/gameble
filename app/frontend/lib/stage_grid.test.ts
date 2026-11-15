import { describe, expect, it } from "vitest"
import { approach, settled, translucent, warp } from "./stage_grid"

describe("stage grid", () => {
  it("leaves the grid flat while the pointer is away", () => {
    expect(warp([100, 100], { x: 140, y: 100, pull: 0 })).toEqual([100, 100])
  })

  it("pushes a point away from the pointer, by a few pixels at most", () => {
    const [x, y] = warp([100, 100], { x: 160, y: 100, pull: 1 })
    expect(x).toBeLessThan(100)
    expect(x).toBeGreaterThan(90)
    expect(y).toBeCloseTo(100)
  })

  it("barely moves the point under the pointer and fades far away", () => {
    const under = warp([100, 100], { x: 101, y: 100, pull: 1 })
    const far = warp([100, 100], { x: 1500, y: 100, pull: 1 })
    expect(Math.abs(under[0] - 100)).toBeLessThan(0.5)
    expect(Math.abs(far[0] - 100)).toBeLessThan(0.01)
  })

  it("eases toward its target and knows when it has arrived", () => {
    expect(approach(0, 100, 0.25)).toBe(25)
    expect(settled({ x: 10, y: 10, pull: 1 }, { x: 10.1, y: 10, pull: 1 })).toBe(true)
    expect(settled({ x: 10, y: 10, pull: 0.5 }, { x: 10, y: 10, pull: 1 })).toBe(false)
  })

  it("turns a token colour translucent", () => {
    expect(translucent("#66c0f4", 0.2)).toBe("rgba(102, 192, 244, 0.2)")
  })
})
