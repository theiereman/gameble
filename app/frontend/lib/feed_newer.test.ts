import { describe, expect, it } from "vitest"
import { anchorShift, newestAction, newestPillShown } from "./feed_newer"

const state = { readerScrolled: true, scrollY: 0, viewportHeight: 800, newerLeft: false }

describe("newestPillShown", () => {
  it("stays hidden until the reader scrolls, even when opened down the feed", () => {
    expect(newestPillShown({ ...state, readerScrolled: false, scrollY: 5000, newerLeft: true })).toBe(false)
  })

  it("shows as soon as the reader scrolls while newer entries are still to load", () => {
    expect(newestPillShown({ ...state, newerLeft: true })).toBe(true)
  })

  it("shows past one screen once every newer entry is loaded, and not before", () => {
    expect(newestPillShown({ ...state, scrollY: 600 })).toBe(false)
    expect(newestPillShown({ ...state, scrollY: 900 })).toBe(true)
  })
})

describe("newestAction", () => {
  it("scrolls up a live feed that holds the newest entries", () => {
    expect(newestAction(true, false)).toBe("scroll")
  })

  it("reopens the feed at its newest when newer entries are left or the feed is not live", () => {
    expect(newestAction(true, true)).toBe("visit")
    expect(newestAction(false, false)).toBe("visit")
  })
})

describe("anchorShift", () => {
  it("is how far the entry in view moved when entries were added above it", () => {
    expect(anchorShift(120, 1920.4)).toBe(1800)
    expect(anchorShift(120, 120)).toBe(0)
  })
})
