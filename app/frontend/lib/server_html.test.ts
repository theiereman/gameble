// @vitest-environment happy-dom
import { describe, expect, it } from "vitest"
import { serverTemplate } from "./server_html"

describe("serverTemplate", () => {
  const html = '<article class="card card--s" data-rarity="rare"><h3 class="card__title">Portal &amp; co</h3></article>'

  it("holds the HTML unchanged as its content, outside the page", () => {
    const template = serverTemplate(html)
    expect(template).toBeInstanceOf(HTMLTemplateElement)
    expect(template.isConnected).toBe(false)
    expect(template.content.querySelector(".card__title")?.textContent).toBe("Portal & co")
    expect(template.content.firstElementChild?.outerHTML).toBe(html)
  })

  it("gives a fresh copy at each clone", () => {
    const template = serverTemplate(html)
    const first = template.content.cloneNode(true) as DocumentFragment
    const second = template.content.cloneNode(true) as DocumentFragment
    expect(first.firstElementChild).not.toBe(second.firstElementChild)
    expect(template.content.childElementCount).toBe(1)
  })

  it("is empty for empty HTML", () => {
    expect(serverTemplate("").content.childNodes).toHaveLength(0)
  })
})
