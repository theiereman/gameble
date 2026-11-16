// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import LinkOpenController from "./link_open_controller"

describe("link-open controller", () => {
  let application: Application
  const fetchMock = vi.fn()

  beforeEach(async () => {
    fetchMock.mockReset().mockResolvedValue({ ok: true })
    vi.stubGlobal("fetch", fetchMock)
    document.head.innerHTML = '<meta name="csrf-token" content="abc">'
    document.body.innerHTML =
      '<a href="#" data-controller="link-open" data-link-open-url-value="/en/links/support/opened" data-action="click->link-open#record auxclick->link-open#record">x</a>'
    application = Application.start()
    application.register("link-open", LinkOpenController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
  })

  it("posts once per click, kept alive and with the CSRF token", () => {
    document.querySelector("a")!.dispatchEvent(new MouseEvent("click", { bubbles: true }))

    expect(fetchMock).toHaveBeenCalledWith(
      "/en/links/support/opened",
      expect.objectContaining({
        method: "POST",
        keepalive: true,
        headers: expect.objectContaining({ "X-CSRF-Token": "abc" }),
      }),
    )
  })

  it("records a middle click too, and survives a failed request", () => {
    fetchMock.mockRejectedValue(new Error("offline"))

    document.querySelector("a")!.dispatchEvent(new MouseEvent("auxclick", { bubbles: true }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})
