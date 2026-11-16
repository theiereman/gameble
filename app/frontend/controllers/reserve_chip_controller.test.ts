// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { dispatchGameble } from "../lib/events"
import { serverTemplate } from "../lib/server_html"
import ReserveChipController from "./reserve_chip_controller"

const STREAM = "<turbo-stream></turbo-stream>"

describe("the booster screen's reserve chip", () => {
  let application: Application
  const send = vi.fn()
  const renderStreamMessage = vi.fn()

  beforeEach(async () => {
    send.mockResolvedValue(new Response(STREAM, { status: 200 }))
    vi.stubGlobal("fetch", send)
    vi.stubGlobal("Turbo", { renderStreamMessage })
    document.body.replaceChildren(
      serverTemplate(`
      <div data-controller="reserve-chip" data-reserve-chip-refresh-url-value="/en/packs-chip?reserve=true"
           data-reserve-chip-full-value="false" data-reserve-chip-next-value="2026-10-02T14:32:00Z">
        <span data-reserve-chip-target="count">9</span>
      </div>`).content,
    )
    application = Application.start()
    application.register("reserve-chip", ReserveChipController)
    await Promise.resolve()
  })

  afterEach(() => {
    application.stop()
    vi.unstubAllGlobals()
    send.mockReset()
    renderStreamMessage.mockReset()
  })

  const bankChanged = (reserveFull: boolean, nextAvailableAt: string | null): void =>
    dispatchGameble("gameble:bank-changed", {
      available: 8,
      special: 0,
      reserveFull,
      nextAvailableAt,
      serverTime: "2026-10-02T14:22:00.000Z",
    })

  it("keeps its countdown while the next capsule's time holds, whatever its precision", () => {
    bankChanged(false, "2026-10-02T14:32:00.000Z")

    expect(document.querySelector("[data-reserve-chip-target=count]")?.textContent).toBe("8")
    expect(send).not.toHaveBeenCalled()
  })

  it("asks the server for itself again once the reserve fills up or its timer moves", async () => {
    bankChanged(true, null)

    await vi.waitFor(() => expect(renderStreamMessage).toHaveBeenCalledWith(STREAM))
    expect(send).toHaveBeenCalledWith("/en/packs-chip?reserve=true", expect.anything())
  })
})
