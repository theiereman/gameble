import { describe, expect, it } from "vitest"
import { COUNT_UP_MS, countedAt } from "./count_up"

describe("countedAt", () => {
  it("starts at zero and lands exactly on the amount", () => {
    expect(countedAt(10_000, 0)).toBe(0)
    expect(countedAt(10_000, COUNT_UP_MS)).toBe(10_000)
    expect(countedAt(10_000, COUNT_UP_MS * 2)).toBe(10_000)
  })

  it("climbs fast then slows, never passing the amount", () => {
    const half = countedAt(10_000, COUNT_UP_MS / 2)
    expect(half).toBeGreaterThan(5_000)
    expect(half).toBeLessThan(10_000)
    expect(countedAt(10_000, COUNT_UP_MS - 1)).toBeLessThanOrEqual(10_000)
  })
})
