import { describe, expect, it } from "vitest"
import { afterLoad, pressed, setsExpanded, viewField } from "./grand_inventory"

describe("afterLoad", () => {
  it("announces the new reading after a scope chip, focuses the view after a tab, and does nothing otherwise", () => {
    expect(afterLoad("scope")).toBe("announce")
    expect(afterLoad("tab")).toBe("focus-view")
    expect(afterLoad(null)).toBe("none")
  })
})

describe("viewField", () => {
  it("leaves the default view out of the address and keeps any other", () => {
    expect(viewField("cards")).toEqual({ value: "cards", disabled: true })
    expect(viewField("pioneers")).toEqual({ value: "pioneers", disabled: false })
  })
})

describe("pressed", () => {
  it("presses the chosen chip only", () => {
    expect(pressed(["all", "current"], "current")).toEqual([false, true])
  })

  it("presses none for a choice that is not a chip", () => {
    expect(pressed(["all", "current"], "other")).toEqual([false, false])
    expect(pressed(["all", "current"], null)).toEqual([false, false])
  })
})

describe("setsExpanded", () => {
  it("unfolds a folded list and folds an unfolded one", () => {
    expect(setsExpanded("false")).toBe(true)
    expect(setsExpanded(null)).toBe(true)
    expect(setsExpanded("true")).toBe(false)
  })
})
