// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ExchangesTabsController from "./exchanges_tabs_controller"
import { serverTemplate } from "../lib/server_html"

const markup = (current: string, kept: string): string => `
  <main id="main">
    <nav aria-label="Trades" data-controller="exchanges-tabs" data-exchanges-tabs-url-value="/en/exchanges/tab"
         data-exchanges-tabs-current-value="${current}" data-exchanges-tabs-kept-value="${kept}">
      <a id="friends" href="/en/trades" ${current === "friends" ? 'aria-current="page"' : ""} data-action="exchanges-tabs#follow">Between friends</a>
      <a id="market" href="/en/market" ${current === "market" ? 'aria-current="page"' : ""} data-action="exchanges-tabs#follow">Market</a>
    </nav>
    <h1 id="title" tabindex="-1">Market</h1>
  </main>`

let application: Application | undefined
let fetchMock: ReturnType<typeof vi.fn>

async function connect(current: string, kept: string): Promise<void> {
  application?.stop()
  document.body.replaceChildren(serverTemplate(markup(current, kept)).content)
  application = new Application()
  application.register("exchanges-tabs", ExchangesTabsController)
  application.start()
  await Promise.resolve()
}

beforeEach(() => {
  fetchMock = vi.fn(() => Promise.resolve(new Response(null, { status: 204 })))
  vi.stubGlobal("fetch", fetchMock)
})

afterEach(() => {
  application?.stop()
  application = undefined
  document.body.replaceChildren()
  document.documentElement.removeAttribute("data-turbo-preview")
  vi.unstubAllGlobals()
})

describe("ExchangesTabsController", () => {
  it("keeps the sub-tab shown when it differs from the kept one", async () => {
    await connect("market", "friends")

    expect(fetchMock).toHaveBeenCalledTimes(1)
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe("/en/exchanges/tab")
    expect(init.method).toBe("POST")
    expect(JSON.parse(init.body as string)).toEqual({ tab: "market" })
  })

  it("posts nothing when the sub-tab shown is already kept", async () => {
    await connect("friends", "friends")

    expect(fetchMock).not.toHaveBeenCalled()
  })

  it("posts nothing on a Turbo preview", async () => {
    document.documentElement.setAttribute("data-turbo-preview", "")
    await connect("market", "friends")

    expect(fetchMock).not.toHaveBeenCalled()
  })

  it("focuses the next screen's heading after a switch to the other sub-tab", async () => {
    await connect("friends", "friends")
    document.getElementById("market")?.addEventListener("click", (event) => event.preventDefault())
    document.getElementById("market")?.click()

    await connect("market", "friends")

    expect(document.activeElement?.id).toBe("title")
  })

  it("leaves the focus alone after a tap on the current sub-tab or a plain visit", async () => {
    await connect("friends", "friends")
    document.getElementById("friends")?.addEventListener("click", (event) => event.preventDefault())
    document.getElementById("friends")?.click()

    await connect("friends", "friends")

    expect(document.activeElement).toBe(document.body)
  })
})
