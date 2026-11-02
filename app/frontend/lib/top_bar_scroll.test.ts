import { describe, expect, it } from "vitest"
import { HIDE_AFTER, SCROLL_DELTA, initialScrollState, nextScrollState } from "./top_bar_scroll"

const scrollTo = (state: typeof initialScrollState, offset: number, holdOpen = false) =>
  nextScrollState(state, { offset, holdOpen })

describe("nextScrollState", () => {
  it("stays shown near the top of the page", () => {
    expect(scrollTo(initialScrollState, HIDE_AFTER).shown).toBe(true)
    expect(scrollTo(initialScrollState, 20).shown).toBe(true)
  })

  it("hides on a downward scroll past the threshold", () => {
    const state = scrollTo({ shown: true, anchor: HIDE_AFTER + 1 }, HIDE_AFTER + 1 + SCROLL_DELTA)
    expect(state.shown).toBe(false)
  })

  it("returns on an upward scroll", () => {
    const hidden = { shown: false, anchor: 400 }
    expect(scrollTo(hidden, 400 - SCROLL_DELTA).shown).toBe(true)
  })

  it("ignores a movement under the delta", () => {
    const hidden = { shown: false, anchor: 400 }
    expect(scrollTo(hidden, 400 - SCROLL_DELTA + 1)).toBe(hidden)
  })

  it("stays shown while a popover is open", () => {
    const state = scrollTo({ shown: true, anchor: 200 }, 600, true)
    expect(state.shown).toBe(true)
  })
})
