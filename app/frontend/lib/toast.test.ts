import { describe, expect, it } from "vitest"
import { TOAST_BASE_MS, toastDuration } from "./toast"

describe("toastDuration", () => {
  it("stays the base time for an empty text", () => {
    expect(toastDuration("")).toBe(TOAST_BASE_MS)
    expect(toastDuration("   ")).toBe(TOAST_BASE_MS)
  })

  it("adds a second for each started group of ten words", () => {
    expect(toastDuration("Proposition envoyée")).toBe(6000)
    expect(toastDuration("un deux trois quatre cinq six sept huit neuf dix")).toBe(6000)
    expect(toastDuration("un deux trois quatre cinq six sept huit neuf dix onze")).toBe(7000)
    expect(toastDuration(Array.from({ length: 30 }, () => "mot").join(" "))).toBe(8000)
  })

  it("counts words across any whitespace", () => {
    expect(toastDuration("  Léa a\n7 jours\tpour répondre. ")).toBe(6000)
  })
})
