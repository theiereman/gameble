import { describe, expect, it } from "vitest"
import { TICKER_MIN_SECONDS, TICKER_PIXELS_PER_SECOND, itemsInView, joinQueued, loopSeconds, repeatsToFill } from "./ticker"

describe("repeatsToFill", () => {
  it("repeats the items until half the track covers the window", () => {
    expect(repeatsToFill(400, 1000)).toBe(3)
    expect(repeatsToFill(500, 1000)).toBe(2)
    expect(repeatsToFill(1200, 1000)).toBe(1)
  })

  it("keeps one run when nothing is measured", () => {
    expect(repeatsToFill(0, 1000)).toBe(1)
    expect(repeatsToFill(400, 0)).toBe(1)
  })
})

describe("loopSeconds", () => {
  it("moves half the track at the steady speed", () => {
    expect(loopSeconds(TICKER_PIXELS_PER_SECOND * 40)).toBe(40)
  })

  it("never loops faster than the shortest loop", () => {
    expect(loopSeconds(10)).toBe(TICKER_MIN_SECONDS)
  })
})

describe("joinQueued", () => {
  it("puts the arrivals first and keeps at most the size", () => {
    expect(joinQueued(["c", "d", "e"], ["a", "b"], 4)).toEqual(["a", "b", "c", "d"])
  })

  it("keeps the items shown when nothing arrived", () => {
    expect(joinQueued(["c", "d"], [], 4)).toEqual(["c", "d"])
  })

  it("keeps only the newest arrivals when they alone pass the size", () => {
    expect(joinQueued(["z"], ["a", "b", "c"], 2)).toEqual(["a", "b"])
  })
})

describe("joinQueued at the loop boundary", () => {
  it("keeps the items in view first and unchanged, the arrivals right after them, the oldest dropped from the end", () => {
    expect(joinQueued(["c", "d", "e", "f"], ["a", "b"], 5, 2)).toEqual(["c", "d", "a", "b", "e"])
  })

  it("keeps the newest arrivals that fit after the items in view, dropping the others", () => {
    expect(joinQueued(["x", "y", "z"], ["a", "b", "c", "d"], 4, 2)).toEqual(["x", "y", "a", "b"])
  })

  it("still joins the newest arrival when the items in view fill the size", () => {
    expect(joinQueued(["x", "y", "z"], ["a", "b"], 3, 3)).toEqual(["x", "y", "z", "a"])
  })
})

describe("itemsInView", () => {
  it("counts the items starting inside the window", () => {
    expect(itemsInView([0, 300, 600, 900, 1200], 1000)).toBe(4)
    expect(itemsInView([], 1000)).toBe(0)
  })
})
