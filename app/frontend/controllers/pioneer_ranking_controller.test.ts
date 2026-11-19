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

describe("the pioneer ranking after a chip or a streamed page", () => {
  let application: Application

  beforeEach(async () => {
    vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => {
      callback(0)
      return 1
    })
    vi.spyOn(history, "replaceState")
    document.body.replaceChildren(
      serverTemplate(`
      <section data-controller="pioneer-ranking" data-action="turbo:frame-load->pioneer-ranking#reloaded">
        <p data-pioneer-ranking-target="status" role="status"></p>
        <div id="pioneer-ranking-results">
          <form data-pioneer-ranking-reading="Season, your place: 4th">
            <button name="period" value="season" aria-pressed="true" data-action="pioneer-ranking#chose">Season</button>
          </form>
        </div>
      </section>`).content,
    )
    application = Application.start()
    application.register("pioneer-ranking", PioneerRankingController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("reads the new period in the status line and keeps focus on the pressed chip", () => {
    const chip = document.querySelector<HTMLButtonElement>("button[name=period]")!
    chip.click()
    document.getElementById("pioneer-ranking-results")!.dispatchEvent(new Event("turbo:frame-load", { bubbles: true }))

    expect(document.querySelector("[role=status]")!.textContent).toBe("Season, your place: 4th")
    expect(document.activeElement).toBe(chip)
  })

  it("moves the address to a streamed page", async () => {
    const marker = document.createElement("span")
    marker.dataset.pioneerRankingTarget = "address"
    marker.dataset.url = "/en/inventory/pioneers?page=2"
    document.querySelector("[data-controller=pioneer-ranking]")!.append(marker)
    await Promise.resolve()

    expect(history.replaceState).toHaveBeenCalledWith(history.state, "", "/en/inventory/pioneers?page=2")
  })
})
