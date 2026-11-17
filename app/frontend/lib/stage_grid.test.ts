import { describe, expect, it } from "vitest"
import { GRID_STEP, HALO_SPAN, approach, gridLines, haloOriginOnGrid, settled, translucent } from "./stage_grid"

describe("stage grid", () => {
  it("eases toward its target and knows when it has arrived", () => {
    expect(approach(0, 100, 0.25)).toBe(25)
    expect(settled({ x: 10, y: 10, pull: 1 }, { x: 10.1, y: 10, pull: 1 })).toBe(true)
    expect(settled({ x: 10, y: 10, pull: 0.5 }, { x: 10, y: 10, pull: 1 })).toBe(false)
  })

  it("turns a token colour translucent", () => {
    expect(translucent("#66c0f4", 0.2)).toBe("rgba(102, 192, 244, 0.2)")
  })

  it("places the lines on the grid step inside a range", () => {
    expect(gridLines(0, 60)).toEqual([0, GRID_STEP, 2 * GRID_STEP])
    expect(gridLines(30, 100)).toEqual([48, 72, 96])
  })

  it("centres the lit patch on the pointer in whole grid steps", () => {
    expect(haloOriginOnGrid(HALO_SPAN / 2)).toBe(0)
    expect(haloOriginOnGrid(HALO_SPAN / 2 + 13)).toBe(GRID_STEP)
    expect(haloOriginOnGrid(HALO_SPAN / 2 - 13)).toBe(-GRID_STEP)
    expect(haloOriginOnGrid(0)).toBe(-HALO_SPAN / 2)
  })
})
