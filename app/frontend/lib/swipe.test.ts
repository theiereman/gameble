import { describe, expect, it } from "vitest"
import { SWIPE_THRESHOLD, swipeStep } from "./swipe"

describe("swipeStep", () => {
  it("goes to the next card for a swipe to the left, the previous one to the right", () => {
    expect(swipeStep(-120, 10)).toBe(1)
    expect(swipeStep(120, -10)).toBe(-1)
  })

  it("counts from the threshold on", () => {
    expect(swipeStep(-SWIPE_THRESHOLD, 0)).toBe(1)
    expect(swipeStep(-(SWIPE_THRESHOLD - 1), 0)).toBe(0)
    expect(swipeStep(SWIPE_THRESHOLD - 1, 0)).toBe(0)
    expect(swipeStep(30, 0, 20)).toBe(-1)
  })

  it("ignores a move that is not mostly horizontal: a scroll", () => {
    expect(swipeStep(-90, 120)).toBe(0)
    expect(swipeStep(90, -90)).toBe(0)
    expect(swipeStep(0, 300)).toBe(0)
  })

  it("ignores a still finger", () => {
    expect(swipeStep(0, 0)).toBe(0)
  })
})
