import { describe, expect, it } from "vitest"
import { clampValue, keyedValue } from "./stepper"

describe("keyedValue", () => {
  it("steps by one, or goes to either end, within 1 and the maximum", () => {
    expect(keyedValue("ArrowUp", 2, 3)).toBe(3)
    expect(keyedValue("ArrowUp", 3, 3)).toBe(3)
    expect(keyedValue("-", 2, 3)).toBe(1)
    expect(keyedValue("ArrowLeft", 1, 3)).toBe(1)
    expect(keyedValue("Home", 3, 3)).toBe(1)
    expect(keyedValue("End", 1, 4)).toBe(4)
  })

  it("answers no other key", () => {
    expect(keyedValue("Enter", 2, 3)).toBeNull()
    expect(keyedValue("Tab", 2, 3)).toBeNull()
  })
})

describe("clampValue", () => {
  it("keeps a value between 1 and the maximum", () => {
    expect(clampValue(0, 3)).toBe(1)
    expect(clampValue(5, 3)).toBe(3)
    expect(clampValue(2, 3)).toBe(2)
  })
})
