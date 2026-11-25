import { describe, expect, it } from "vitest"
import { parsePrice } from "./order_form"

describe("parsePrice", () => {
  it("reads grouped digits and refuses blanks, zero and text", () => {
    expect(parsePrice("1,000")).toBe(1000)
    expect(parsePrice("")).toBeNull()
    expect(parsePrice("0")).toBeNull()
    expect(parsePrice("abc")).toBeNull()
  })
})
