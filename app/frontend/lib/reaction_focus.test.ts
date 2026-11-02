import { describe, expect, it } from "vitest"
import { FOCUS_WINDOW_MS, PressedFocus } from "./reaction_focus"

describe("PressedFocus", () => {
  it("gives back the pressed kind to the bar that replaced the pressed one, once", () => {
    const focus = new PressedFocus()
    focus.remember("reactions-a", "heart", 1_000)

    expect(focus.take("reactions-a", 1_200)).toBe("heart")
    expect(focus.take("reactions-a", 1_300)).toBeNull()
  })

  it("leaves another entry's bar alone", () => {
    const focus = new PressedFocus()
    focus.remember("reactions-a", "wow", 0)

    expect(focus.take("reactions-b", 10)).toBeNull()
    expect(focus.take("reactions-a", 20)).toBe("wow")
  })

  it("forgets a press the answer took too long to follow", () => {
    const focus = new PressedFocus()
    focus.remember("reactions-a", "gg", 0)

    expect(focus.take("reactions-a", FOCUS_WINDOW_MS + 1)).toBeNull()
  })
})
