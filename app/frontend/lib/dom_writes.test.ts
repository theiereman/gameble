// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest"
import { writeData, writeFlag, writeText } from "./dom_writes"

describe("writeText", () => {
  it("writes the text only when it differs, and ignores a missing element", () => {
    const element = document.createElement("span")
    element.textContent = "a"
    const first = element.firstChild
    writeText(element, "a")
    expect(element.firstChild).toBe(first)
    writeText(element, "b")
    expect(element.textContent).toBe("b")
    expect(() => writeText(null, "c")).not.toThrow()
  })
})

describe("writeData", () => {
  it("sets the value, leaves an equal one alone and removes it for null", () => {
    const element = document.createElement("div")
    writeData(element, "depth", "2")
    expect(element.dataset.depth).toBe("2")
    const observer = vi.fn()
    new MutationObserver(observer).observe(element, { attributes: true })
    writeData(element, "depth", "2")
    expect(observer).not.toHaveBeenCalled()
    writeData(element, "depth", null)
    expect("depth" in element.dataset).toBe(false)
    writeData(element, "depth", null)
    expect("depth" in element.dataset).toBe(false)
  })
})

describe("writeFlag", () => {
  it("sets the attribute to true or removes it", () => {
    const element = document.createElement("a")
    writeFlag(element, "aria-disabled", true)
    expect(element.getAttribute("aria-disabled")).toBe("true")
    writeFlag(element, "aria-disabled", false)
    expect(element.hasAttribute("aria-disabled")).toBe(false)
  })
})
