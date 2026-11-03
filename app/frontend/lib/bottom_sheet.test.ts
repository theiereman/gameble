import { describe, expect, it } from "vitest"
import { DISMISS_DISTANCE, dismisses, dragOffset, focusWrapTarget } from "./bottom_sheet"

describe("dragOffset", () => {
  it("follows a finger moving down", () => {
    expect(dragOffset(100, 180)).toBe(80)
  })

  it("never lifts the sheet above its place", () => {
    expect(dragOffset(100, 40)).toBe(0)
    expect(dragOffset(100, 100)).toBe(0)
  })
})

describe("dismisses", () => {
  it("closes a tall sheet from the fixed distance on", () => {
    expect(dismisses(DISMISS_DISTANCE, 600)).toBe(true)
    expect(dismisses(200, 600)).toBe(true)
    expect(dismisses(DISMISS_DISTANCE - 1, 600)).toBe(false)
    expect(dismisses(30, 600)).toBe(false)
  })

  it("closes a short sheet from a third of its height", () => {
    expect(dismisses(40, 120)).toBe(true)
    expect(dismisses(39, 120)).toBe(false)
  })

  it("keeps a sheet that has not moved", () => {
    expect(dismisses(0, 0)).toBe(false)
    expect(dismisses(0, 600)).toBe(false)
  })
})

describe("focusWrapTarget", () => {
  const items = ["close", "first choice", "last choice"]

  it("wraps Tab from the last element to the first", () => {
    expect(focusWrapTarget(items, "last choice", false)).toBe("close")
  })

  it("wraps Shift+Tab from the first element to the last", () => {
    expect(focusWrapTarget(items, "close", true)).toBe("last choice")
  })

  it("leaves the move to the browser between the ends", () => {
    expect(focusWrapTarget(items, "first choice", false)).toBeUndefined()
    expect(focusWrapTarget(items, "first choice", true)).toBeUndefined()
    expect(focusWrapTarget(items, "close", false)).toBeUndefined()
    expect(focusWrapTarget(items, "last choice", true)).toBeUndefined()
  })

  it("brings back a focus found outside", () => {
    expect(focusWrapTarget(items, null, false)).toBe("close")
    expect(focusWrapTarget(items, "elsewhere", true)).toBe("last choice")
  })

  it("has nothing to wrap to in an empty sheet", () => {
    expect(focusWrapTarget([], null, false)).toBeUndefined()
  })
})
