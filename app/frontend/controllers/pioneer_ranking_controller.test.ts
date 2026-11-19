// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import PioneerRankingController from "./pioneer_ranking_controller"
import { serverTemplate } from "../lib/server_html"

const GO_AND_FOCUS = "pioneer-ranking#go focusin->pioneer-ranking#barFocused focusout->pioneer-ranking#barLeft"

type Watch = (entries: Array<Pick<IntersectionObserverEntry, "isIntersecting" | "target">>) => void

describe("the viewer's place on the pioneer ranking", () => {
  let application: Application
  let watch: Watch | undefined

  beforeEach(async () => {
    watch = undefined
    vi.stubGlobal(
      "IntersectionObserver",
      class {
        constructor(callback: Watch) {
          watch = callback
        }
        observe(): void {}
        unobserve(): void {}
        disconnect(): void {}
      },
    )
    Element.prototype.scrollIntoView = vi.fn()
    document.body.replaceChildren(
      serverTemplate(`
      <section data-controller="pioneer-ranking">
        <p data-pioneer-ranking-target="status" role="status"></p>
        <div class="pioneer-place" data-pioneer-ranking-target="place">
          <a class="pioneer-place__link" href="/en/inventory/pioneers?page=1#pioneer-ranking-me"
             data-action="${GO_AND_FOCUS}">Your place</a>
        </div>
        <button type="button">Elsewhere</button>
        <ol><li id="pioneer-ranking-me" tabindex="-1" data-pioneer-ranking-target="mine">Hugo</li></ol>
      </section>`).content,
    )
    application = Application.start()
    application.register("pioneer-ranking", PioneerRankingController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
  })

  const place = (): HTMLElement => document.querySelector(".pioneer-place")!
  const link = (): HTMLAnchorElement => document.querySelector(".pioneer-place__link")!
  const row = (): HTMLElement => document.getElementById("pioneer-ranking-me")!
  const pinned = (): boolean => place().classList.contains("pioneer-place--pinned")
  const rowSeen = (isIntersecting: boolean): void => watch?.([{ isIntersecting, target: row() }])

  it("pins the place while the viewer's row is off screen", () => {
    rowSeen(false)
    expect(pinned()).toBe(true)
    rowSeen(true)
    expect(pinned()).toBe(false)
  })

  it("keeps the place pinned while focus is inside it", () => {
    rowSeen(true)
    link().focus()
    expect(pinned()).toBe(true)
    document.querySelector<HTMLButtonElement>("button")!.focus()
    expect(pinned()).toBe(false)
  })

  it("pins the place when the viewer's row is on another page", async () => {
    row().remove()
    await Promise.resolve()
    expect(pinned()).toBe(true)
  })

  it("moves focus to the viewer's row on this page instead of loading it", () => {
    const click = new MouseEvent("click", { bubbles: true, cancelable: true })
    link().dispatchEvent(click)
    expect(click.defaultPrevented).toBe(true)
    expect(document.activeElement).toBe(row())
    expect(row().scrollIntoView).toHaveBeenCalledWith({ block: "center" })
  })
})
