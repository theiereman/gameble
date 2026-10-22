import { describe, expect, it } from "vitest"
import { overflowsSideways } from "./overflow_focus"

describe("overflowsSideways", () => {
  it("is true only when the content is wider than the row", () => {
    expect(overflowsSideways({ scrollWidth: 1296, clientWidth: 350 })).toBe(true)
    expect(overflowsSideways({ scrollWidth: 350, clientWidth: 350 })).toBe(false)
  })
})
