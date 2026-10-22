import { describe, expect, it } from "vitest"
import { crossedPowerLine, currentModuleIndex, driftOffsets, scrollFill, staggerDelayMs } from "./landing_scroll"

describe("crossedPowerLine", () => {
  it("is false below the 85% line", () => {
    expect(crossedPowerLine(900, 1000)).toBe(false)
  })

  it("is true on the line and above it", () => {
    expect(crossedPowerLine(850, 1000)).toBe(true)
    expect(crossedPowerLine(-300, 1000)).toBe(true)
  })
})

describe("currentModuleIndex", () => {
  it("is the hero when no top reaches the 40% line", () => {
    expect(currentModuleIndex([500, 1200, 2000], 1000)).toBe(0)
  })

  it("is the last module at or above the line", () => {
    expect(currentModuleIndex([-900, -300, 400, 1200], 1000)).toBe(2)
    expect(currentModuleIndex([-900, -300, 401, 1200], 1000)).toBe(1)
  })

  it("is the last module once the page ends", () => {
    expect(currentModuleIndex([-900, -300, 401, 1200], 1000, true)).toBe(3)
  })
})

describe("scrollFill", () => {
  it("fills proportionally between none and all segments", () => {
    expect(scrollFill(0, 4000, 24)).toBe(0)
    expect(scrollFill(2000, 4000, 24)).toBe(12)
    expect(scrollFill(4000, 4000, 24)).toBe(24)
  })

  it("gives 0 without scrollable height and clamps overscroll", () => {
    expect(scrollFill(100, 0, 24)).toBe(0)
    expect(scrollFill(5000, 4000, 24)).toBe(24)
    expect(scrollFill(-50, 4000, 24)).toBe(0)
  })
})

describe("driftOffsets", () => {
  it("moves the near layer faster than the far one", () => {
    expect(driftOffsets(1000)).toEqual({ near: 120, far: 50 })
    expect(driftOffsets(0)).toEqual({ near: 0, far: 0 })
  })
})

describe("staggerDelayMs", () => {
  it("steps by index", () => {
    expect(staggerDelayMs(0, 70)).toBe(0)
    expect(staggerDelayMs(3, 70)).toBe(210)
  })
})
