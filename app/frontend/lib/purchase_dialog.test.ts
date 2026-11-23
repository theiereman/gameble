// @vitest-environment happy-dom
import { beforeEach, describe, expect, it } from "vitest"
import { serverTemplate } from "./server_html"
import { focusTarget, returnPoint } from "./purchase_dialog"

describe("purchase dialog return point", () => {
  beforeEach(() => {
    document.body.replaceChildren(
      serverTemplate(
        '<h1 id="heading" tabindex="-1">Shop</h1><ul>' +
          '<li id="one"><a href="/1">One</a></li>' +
          '<li id="two"><a href="/2">Two</a></li>' +
          '<li id="three"><a href="/3">Three</a></li></ul>',
      ).content,
    )
  })

  const link = (id: string): HTMLElement => document.querySelector<HTMLElement>(`#${id} a`)!
  const heading = (): HTMLElement => document.getElementById("heading")!
  const byId = (id: string): Element | null => document.getElementById(id)

  it("returns to the tile redrawn under the same id", () => {
    const point = returnPoint(link("two"), heading())
    document.getElementById("two")!.replaceWith(serverTemplate('<li id="two"><a href="/2">Two again</a></li>').content)

    expect(focusTarget(point, byId)?.textContent).toBe("Two again")
  })

  it("falls back to the next tile when the tile left", () => {
    const point = returnPoint(link("two"), heading())
    document.getElementById("two")!.remove()

    expect(focusTarget(point, byId)).toBe(link("three"))
  })

  it("falls back to the previous tile, then the heading", () => {
    const point = returnPoint(link("three"), heading())
    document.getElementById("three")!.remove()
    expect(focusTarget(point, byId)).toBe(link("two"))

    const lone = returnPoint(link("one"), heading())
    document.querySelector("ul")!.remove()
    expect(focusTarget(lone, byId)).toBe(heading())
  })
})
