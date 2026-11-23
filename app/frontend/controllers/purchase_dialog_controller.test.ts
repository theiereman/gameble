// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { serverTemplate } from "../lib/server_html"
import PurchaseDialogController from "./purchase_dialog_controller"

describe("purchase-dialog controller", () => {
  let application: Application
  const reload = vi.fn()

  beforeEach(async () => {
    document.body.replaceChildren(
      serverTemplate(
        '<section data-controller="purchase-dialog">' +
          '<h1 tabindex="-1" data-purchase-dialog-target="heading">Shop</h1><ul>' +
          '<li id="one"><a href="/shop/one" data-action="purchase-dialog#open">One</a></li>' +
          '<li id="two"><a href="/shop/two" data-action="purchase-dialog#open">Two</a></li></ul>' +
          '<dialog data-purchase-dialog-target="dialog" data-action="close->purchase-dialog#closed">' +
          '<div id="frame" data-purchase-dialog-target="frame"><p>Old</p></div>' +
          '<template data-purchase-dialog-target="loading"><p class="loading">Loading</p></template>' +
          '<template data-purchase-dialog-target="failed"><p class="failed">Not loaded. ' +
          '<button type="button" data-action="purchase-dialog#retry">Try again</button></p></template>' +
          "</dialog></section>",
      ).content,
    )
    reload.mockReset()
    Object.assign(document.getElementById("frame")!, { reload })
    application = Application.start()
    application.register("purchase-dialog", PurchaseDialogController)
    await Promise.resolve()
  })

  afterEach(() => application.stop())

  const frame = (): HTMLElement => document.getElementById("frame")!
  const dialog = (): HTMLDialogElement => document.querySelector("dialog")!
  const click = (id: string): MouseEvent => {
    const event = new MouseEvent("click", { bubbles: true, cancelable: true })
    document.querySelector(`#${id} a`)!.dispatchEvent(event)
    return event
  }

  it("opens the dialog on the loading line and loads the tile's confirmation in the frame", () => {
    const event = click("one")

    expect(event.defaultPrevented).toBe(true)
    expect(dialog().open).toBe(true)
    expect(frame().querySelector(".loading")).not.toBeNull()
    expect(frame().getAttribute("src")).toBe(new URL("/shop/one", document.baseURI).href)
    expect(reload).not.toHaveBeenCalled()
  })

  it("reloads the frame when the same tile opens it again, for a fresh confirmation", () => {
    click("one")
    dialog().close()

    click("one")

    expect(reload).toHaveBeenCalledTimes(1)
  })

  it("focuses the confirmation's title once it arrives", async () => {
    click("one")

    frame().replaceChildren(serverTemplate('<h2 tabindex="-1" data-purchase-dialog-target="title">Buy?</h2>').content)
    await Promise.resolve()

    expect(document.activeElement?.textContent).toBe("Buy?")
  })

  it.each(["turbo:frame-missing", "turbo:fetch-request-error"])(
    "writes the failure line with its retry into the frame on %s, and retries on the loading line",
    async (name) => {
      click("one")
      const event = new Event(name, { bubbles: true, cancelable: true })
      frame().dispatchEvent(event)

      expect(event.defaultPrevented).toBe(true)
      expect(frame().querySelector(".failed")).not.toBeNull()

      await Promise.resolve()
      frame().querySelector("button")!.click()

      expect(frame().querySelector(".loading")).not.toBeNull()
      expect(reload).toHaveBeenCalledTimes(1)
    },
  )

  it("leaves a failure to Turbo when the page has no failure line", () => {
    document.querySelector("[data-purchase-dialog-target='failed']")!.remove()
    const event = new Event("turbo:frame-missing", { bubbles: true, cancelable: true })
    frame().dispatchEvent(event)

    expect(event.defaultPrevented).toBe(false)
  })

  it("moves focus to the next tile when the opener left while the dialog was open", () => {
    click("one")
    document.getElementById("one")!.remove()

    dialog().close()
    dialog().dispatchEvent(new Event("close"))

    expect(document.activeElement).toBe(document.querySelector("#two a"))
  })
})
