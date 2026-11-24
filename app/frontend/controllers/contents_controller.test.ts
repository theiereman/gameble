// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ContentsController from "./contents_controller"
import { serverTemplate } from "../lib/server_html"

type Watch = (entries: Array<Pick<IntersectionObserverEntry, "isIntersecting" | "target">>) => void

describe("the table of contents", () => {
  let application: Application
  let watch: Watch | undefined
  const observed: Element[] = []

  beforeEach(async () => {
    observed.length = 0
    vi.stubGlobal(
      "IntersectionObserver",
      class {
        constructor(callback: Watch) {
          watch = callback
        }
        observe(element: Element): void {
          observed.push(element)
        }
        disconnect(): void {}
      },
    )
    document.body.replaceChildren(
      serverTemplate(`
      <nav data-controller="contents">
        <a href="#packs" data-contents-target="link">Packs</a>
        <a href="#shop" data-contents-target="link">Shop</a>
      </nav>
      <h2 id="packs">Packs</h2>
      <h2 id="shop">Shop</h2>`).content,
    )
    application = Application.start()
    application.register("contents", ContentsController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
  })

  const current = (): string[] =>
    [...document.querySelectorAll("a[aria-current=location]")].map((link) => link.textContent ?? "")

  it("watches the heading of every link", () => {
    expect(observed.map((heading) => heading.id)).toEqual(["packs", "shop"])
  })

  it("marks only the link of the heading that crossed the reading line", () => {
    watch?.([{ isIntersecting: true, target: document.getElementById("shop")! }])
    expect(current()).toEqual(["Shop"])

    watch?.([{ isIntersecting: false, target: document.getElementById("shop")! }])
    expect(current()).toEqual(["Shop"])

    watch?.([{ isIntersecting: true, target: document.getElementById("packs")! }])
    expect(current()).toEqual(["Packs"])
  })
})
