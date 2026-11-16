// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import HubFoldController, { FOLD_MS } from "./hub_fold_controller"
import { serverTemplate } from "../lib/server_html"

describe("the hub panel fold", () => {
  let application: Application
  const animate = vi.fn()

  beforeEach(async () => {
    HTMLElement.prototype.animate = animate
    document.body.replaceChildren(
      serverTemplate(`
      <section class="panel">
        <button type="button" aria-expanded="false" data-controller="hub-fold" data-action="hub-fold#toggle"></button>
      </section>`).content,
    )
    application = Application.start()
    application.register("hub-fold", HubFoldController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    animate.mockReset()
    delete document.documentElement.dataset.motion
  })

  const button = (): HTMLButtonElement => document.querySelector("button")!

  it("unfolds and folds again, animating the panel's height each time", () => {
    button().click()
    expect(button().getAttribute("aria-expanded")).toBe("true")
    button().click()
    expect(button().getAttribute("aria-expanded")).toBe("false")
    expect(animate).toHaveBeenCalledTimes(2)
    expect(animate.mock.calls[0][1]).toMatchObject({ duration: FOLD_MS })
    expect(animate.mock.calls[0][0][0]).toHaveProperty("height")
  })

  it("under reduced motion, folds without animating", () => {
    document.documentElement.dataset.motion = "reduced"
    button().click()
    expect(button().getAttribute("aria-expanded")).toBe("true")
    expect(animate).not.toHaveBeenCalled()
  })
})
