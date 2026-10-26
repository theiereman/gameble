// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import { cloneTemplate } from "./booster_templates"

const template = (build: (content: DocumentFragment) => void): HTMLTemplateElement => {
  const element = document.createElement("template")
  build(element.content)
  return element
}

describe("cloneTemplate", () => {
  it("clones the first element without the whitespace between its tags", () => {
    const source = template((content) => {
      const card = document.createElement("li")
      card.append("\n  ", document.createElement("span"), "\n  ", document.createElement("b"), "\n")
      content.append("\n", card, "\n")
    })

    const clone = cloneTemplate(source)

    expect(clone?.tagName).toBe("LI")
    expect(Array.from(clone?.childNodes ?? [], (node) => node.nodeName)).toEqual(["SPAN", "B"])
    expect(source.content.querySelector("li")?.childNodes.length).toBe(5)
  })

  it("keeps the words", () => {
    const source = template((content) => {
      const line = document.createElement("p")
      line.append("? ? ?")
      content.append(line)
    })

    expect(cloneTemplate(source)?.textContent).toBe("? ? ?")
  })

  it("answers null for an empty template", () => {
    expect(cloneTemplate(template(() => {}))).toBeNull()
  })
})
