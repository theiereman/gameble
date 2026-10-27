// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import { cloneContent, cloneFirstElement, cloneTemplate } from "./templates"

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

describe("cloneContent, cloneFirstElement", () => {
  it("clone the whole content, or its first element with the whitespace kept", () => {
    const source = template((content) => {
      const item = document.createElement("li")
      item.append("\n ", document.createElement("span"))
      content.append("\n", item, document.createElement("p"))
    })

    expect(cloneContent(source)).not.toBe(source.content)
    expect(cloneContent(source).children.length).toBe(2)
    expect(cloneFirstElement(source)?.childNodes.length).toBe(2)
    expect(cloneFirstElement(template(() => {}))).toBeNull()
  })
})
