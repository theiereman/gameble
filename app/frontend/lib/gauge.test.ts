import { describe, expect, it } from "vitest"
import { litSegments } from "./gauge"

describe("litSegments", () => {
  it("lights whole segments only, from none to all", () => {
    expect(litSegments(0, 86400, 24)).toBe(0)
    expect(litSegments(3599, 86400, 24)).toBe(0)
    expect(litSegments(3600, 86400, 24)).toBe(1)
    expect(litSegments(81015, 86400, 24)).toBe(22)
    expect(litSegments(86400, 86400, 24)).toBe(24)
  })

  it("clamps the value and lights nothing without a maximum", () => {
    expect(litSegments(-5, 100, 24)).toBe(0)
    expect(litSegments(500, 100, 24)).toBe(24)
    expect(litSegments(10, 0, 24)).toBe(0)
  })
})
