// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest"
import { writeAttribute, writeData, writeDisabled, writeFlag, writeHidden, writeText } from "./dom_writes"

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

describe("writes that leave an unchanged element alone", () => {
  function mutationsOf(element: Element, write: () => void): number {
    const observer = new MutationObserver(() => {})
    observer.observe(element, { attributes: true })
    write()
    const count = observer.takeRecords().length
    observer.disconnect()
    return count
  }

  it("writes an attribute, a hidden flag or a disabled flag only when it changes", () => {
    const button = document.createElement("button")
    expect(mutationsOf(button, () => writeAttribute(button, "aria-pressed", "true"))).toBe(1)
    expect(mutationsOf(button, () => writeAttribute(button, "aria-pressed", "true"))).toBe(0)
    expect(mutationsOf(button, () => writeHidden(button, true))).toBe(1)
    expect(mutationsOf(button, () => writeHidden(button, true))).toBe(0)
    expect(button.hidden).toBe(true)
    expect(mutationsOf(button, () => writeDisabled(button, false))).toBe(0)
    expect(mutationsOf(button, () => writeDisabled(button, true))).toBe(1)
    expect(mutationsOf(button, () => writeFlag(button, "aria-busy", false))).toBe(0)
    expect(() => writeHidden(null, true)).not.toThrow()
    expect(() => writeDisabled(null, true)).not.toThrow()
  })
})
