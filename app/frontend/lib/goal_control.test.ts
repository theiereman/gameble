// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import { BOUGHT_GUARD_MS, guarded, targetsControl } from "./goal_control"

describe("goal control", () => {
  const stream = (target: string): Element => {
    const element = document.createElement("turbo-stream")
    element.setAttribute("target", target)
    return element
  }

  it("answers only to a stream aimed at the control", () => {
    expect(targetsControl(stream("set-album-goal"), "set-album-goal")).toBe(true)
    expect(targetsControl(stream("slot-purchase"), "set-album-goal")).toBe(false)
  })

  it("ignores presses for a moment after a slot is bought, and never before one", () => {
    expect(guarded(null, 1_000)).toBe(false)
    expect(guarded(1_000, 1_000)).toBe(true)
    expect(guarded(1_000, 1_000 + BOUGHT_GUARD_MS - 1)).toBe(true)
    expect(guarded(1_000, 1_000 + BOUGHT_GUARD_MS)).toBe(false)
  })
})
