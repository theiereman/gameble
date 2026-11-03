import { describe, expect, it } from "vitest"
import { drawSettled, nearNow, sighted } from "./approach"

describe("sighted", () => {
  it("draws a card's art as it comes near", () => {
    expect(sighted("far", true)).toEqual({ approach: "drawing", act: "draw" })
    expect(sighted("far", false)).toEqual({ approach: "far", act: "none" })
  })

  it("gives the draw up when the card leaves before it settles, to draw again on the next approach", () => {
    const left = sighted("drawing", false)
    expect(left).toEqual({ approach: "far", act: "give-up" })
    expect(sighted(left.approach, true)).toEqual({ approach: "drawing", act: "draw" })
  })

  it("keeps a draw under way while the card stays near", () => {
    expect(sighted("drawing", true)).toEqual({ approach: "drawing", act: "none" })
  })

  it("leaves a settled art alone, near or far", () => {
    expect(sighted("settled", true)).toEqual({ approach: "settled", act: "none" })
    expect(sighted("settled", false)).toEqual({ approach: "settled", act: "none" })
  })
})

describe("drawSettled", () => {
  it("settles a draw under way, and nothing else", () => {
    expect(drawSettled("drawing")).toBe("settled")
    expect(drawSettled("far")).toBe("far")
    expect(drawSettled("settled")).toBe("settled")
  })
})

describe("nearNow", () => {
  it("reads the card's latest crossing, an empty batch telling nothing", () => {
    expect(nearNow([{ isIntersecting: true }, { isIntersecting: false }])).toBe(false)
    expect(nearNow([{ isIntersecting: false }, { isIntersecting: true }])).toBe(true)
    expect(nearNow([])).toBeUndefined()
  })
})
