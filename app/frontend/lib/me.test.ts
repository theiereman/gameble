import { describe, expect, it } from "vitest"
import { wear, wornBack } from "./me"

describe("wornBack", () => {
  it("starts on the back the page was rendered with, its season unknown", () => {
    expect(wornBack("standard")).toEqual({ back: "standard", season: null })
  })
})

describe("wear", () => {
  const standard = wornBack("standard")

  it("wears another back", () => {
    expect(wear(standard, { back: "set-theme-rpg", season: null })).toEqual({ back: "set-theme-rpg", season: null })
  })

  it("keeps the season mark the back is worn with", () => {
    expect(wear(standard, { back: "set-theme-rpg", season: 2 })).toEqual({ back: "set-theme-rpg", season: 2 })
  })

  it("takes a missing season for none", () => {
    expect(wear(standard, { back: "set-theme-rpg" })).toEqual({ back: "set-theme-rpg", season: null })
  })

  it("wears the same back with another mark", () => {
    const worn = { back: "set-theme-rpg", season: 1 }
    expect(wear(worn, { back: "set-theme-rpg", season: 2 })).toEqual({ back: "set-theme-rpg", season: 2 })
  })

  it("ignores a choice that changes nothing", () => {
    expect(wear(standard, { back: "standard", season: null })).toBeNull()
    expect(wear({ back: "set-theme-rpg", season: 1 }, { back: "set-theme-rpg", season: 1 })).toBeNull()
  })

  it("ignores a detail that names no back", () => {
    expect(wear(standard, null)).toBeNull()
    expect(wear(standard, "set-theme-rpg")).toBeNull()
    expect(wear(standard, {})).toBeNull()
    expect(wear(standard, { back: "" })).toBeNull()
    expect(wear(standard, { back: 3 })).toBeNull()
  })

  it("ignores a season that is not a season number", () => {
    expect(wear(standard, { back: "set-theme-rpg", season: "2" })).toBeNull()
    expect(wear(standard, { back: "set-theme-rpg", season: 0 })).toBeNull()
    expect(wear(standard, { back: "set-theme-rpg", season: 1.5 })).toBeNull()
  })
})
