// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import { BANNER_TIERS, opensElsewhere } from "./screen"

describe("opensElsewhere", () => {
  it("is true for a click that is not a plain primary one", () => {
    expect(opensElsewhere(new MouseEvent("click"))).toBe(false)
    expect(opensElsewhere(new MouseEvent("click", { button: 1 }))).toBe(true)
    for (const modifier of ["metaKey", "ctrlKey", "shiftKey", "altKey"]) {
      expect(opensElsewhere(new MouseEvent("click", { [modifier]: true }))).toBe(true)
    }
  })

  it("is false for an event that is not a mouse one", () => {
    expect(opensElsewhere(new Event("click"))).toBe(false)
    expect(opensElsewhere(new KeyboardEvent("keydown", { metaKey: true }))).toBe(false)
  })
})

describe("BANNER_TIERS", () => {
  it("are the tiers that get a banner and rays", () => {
    expect(BANNER_TIERS).toEqual(["epic", "legendary"])
  })
})
