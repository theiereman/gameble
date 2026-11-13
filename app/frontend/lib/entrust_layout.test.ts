import { describe, expect, it } from "vitest"
import { start, toggle, type Copy } from "./entrust"
import { idle, layoutAsked, layoutFor, sheetShown } from "./entrust_layout"

const copy = (ref: string): Copy => ({
  ref,
  title: `Game ${ref}`,
  rarity: "rare",
  season: 1,
  free: 2,
  owned: 2,
  value: 5000,
})

const begin = () => toggle(start([copy("a"), copy("b")], 100_000, {}), "a")

describe("layoutFor", () => {
  it("names the layout of the phone query", () => {
    expect([layoutFor(true), layoutFor(false)]).toEqual(["phone", "wide"])
  })
})

describe("a layout asked while no sheet is open", () => {
  it("applies at once", () => {
    const state = layoutAsked(begin(), "phone")
    expect([state.layout, state.pendingLayout]).toEqual(["phone", null])
  })

  it("is a no-op when it asks the current layout", () => {
    const state = begin()
    expect(layoutAsked(state, "wide")).toBe(state)
  })
})

describe("a layout asked while the sheet is open", () => {
  it("is held, the layout unchanged", () => {
    const state = layoutAsked(sheetShown(begin(), true), "phone")
    expect([state.layout, state.pendingLayout, idle(state)]).toEqual(["wide", "phone", false])
  })

  it("is applied once when the sheet closes", () => {
    const held = layoutAsked(sheetShown(begin(), true), "phone")
    const closed = sheetShown(held, false)
    expect([closed.layout, closed.pendingLayout, closed.sheetOpen]).toEqual(["phone", null, false])
  })

  it("leaves no change when it is asked then reverted", () => {
    const held = layoutAsked(layoutAsked(sheetShown(begin(), true), "phone"), "wide")
    expect(held.pendingLayout).toBeNull()
    const closed = sheetShown(held, false)
    expect(closed.layout).toBe("wide")
  })
})

describe("the sheet", () => {
  it("records opening and ignores a repeat", () => {
    const open = sheetShown(begin(), true)
    expect(open.sheetOpen).toBe(true)
    expect(sheetShown(open, true)).toBe(open)
  })
})

describe("a switch", () => {
  it("leaves the ticks and the active cell untouched", () => {
    const before = begin()
    const after = sheetShown(layoutAsked(sheetShown(before, true), "phone"), false)
    expect([after.ticked, after.active]).toEqual([before.ticked, before.active])
  })
})
