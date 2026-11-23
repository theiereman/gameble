// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { serverTemplate } from "../lib/server_html"
import type { Totals } from "../lib/wanted_table"
import WantedDockController, { STATUS_DELAY } from "./wanted_dock_controller"
import type { WantedStrings } from "./wanted_table_controller"

const amount = (target: string): string =>
  `<span class="picoin-amount" role="img" data-wanted-dock-target="${target}"><span class="picoin-amount__figure">0</span></span>`

const MARKUP = (refusal: string): string => `
  <aside id="dock" data-controller="wanted-dock" data-wanted-dock-locale-value="en" data-wanted-dock-accessible-value="%{amount} PiCoins">
    ${amount("now")}
    <span id="sales" data-wanted-dock-target="salesPart" hidden><span data-wanted-dock-target="salesCount"></span>${amount("salesAmount")}</span>
    <span id="entrusted" data-wanted-dock-target="entrustedPart" hidden><span data-wanted-dock-target="entrustedCount"></span>${amount("entrustedAmount")}</span>
    <span id="listed" data-wanted-dock-target="listedCount"></span>${amount("listedAmount")}
    ${amount("stamps")}
    <p id="over" data-wanted-dock-target="over" hidden></p>
    <p id="refusal" data-wanted-dock-target="refusal" ${refusal ? "" : "hidden"}>${refusal}</p>
    <span class="wanted-dock__all"><button type="submit" name="all" value="1">ENTRUST ALL ANYWAY</button></span>
    <p id="status" role="status" aria-live="polite" data-wanted-dock-target="status"></p>
  </aside>`

const STRINGS: WantedStrings = {
  amount: "%{amount} PiCoins",
  now: "now",
  atStart: "at the start",
  changedTo: "Your choice is now %{choice}.",
  choiceOrder: "TO THE ORDER",
  choiceAuction: "AUCTION",
  choiceEntrust: "ENTRUST",
  sales: { one: "1 sale to an order", other: "%{count} sales to orders" },
  entrusted: { one: "1 card entrusted", other: "%{count} cards entrusted" },
  listed: { one: "1 card at the starting price", other: "%{count} cards at the starting price" },
  allEntrust: "ENTRUST ALL ANYWAY · %{amount}",
  status: "You receive %{amount} now.",
  overCap: {
    one: "%{count} copy will exceed your daily cap: %{cards}.",
    other: "%{count} copies will exceed your daily cap: %{cards}.",
  },
}

const sums = (over: Partial<Totals> = {}): Totals => ({
  now: 1_580,
  sales: 2,
  salesAmount: 1_530,
  entrusted: 1,
  entrustedAmount: 50,
  listed: 0,
  listedAmount: 0,
  stamps: 0,
  allEntrust: 2_000,
  over: 0,
  overTitles: [],
  lines: {},
  ...over,
})

let application: Application

const mount = async (refusal = ""): Promise<WantedDockController> => {
  document.body.replaceChildren(serverTemplate(MARKUP(refusal)).content)
  application = new Application()
  await application.start()
  application.register("wanted-dock", WantedDockController)
  return application.getControllerForElementAndIdentifier(
    document.getElementById("dock")!,
    "wanted-dock",
  ) as WantedDockController
}

const text = (id: string): string => document.getElementById(id)!.textContent ?? ""

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
  application.stop()
})

describe("the wanted table's dock", () => {
  it("draws each total, leaves out a part at zero and prices entrusting everything", async () => {
    const dock = await mount()
    dock.render(sums({ over: 1, overTitles: ["Pyre"] }), STRINGS)
    expect(document.querySelector("[data-wanted-dock-target=now]")!.getAttribute("aria-label")).toBe("1,580 PiCoins")
    expect(text("sales")).toContain("2 sales to orders")
    expect(document.getElementById("sales")!.hidden).toBe(false)
    expect(document.getElementById("entrusted")!.hidden).toBe(false)
    expect(text("listed")).toBe("0 cards at the starting price")
    expect(text("over")).toBe("1 copy will exceed your daily cap: Pyre.")
    expect(document.querySelector("button")!.textContent).toBe("ENTRUST ALL ANYWAY · 2,000")
    dock.render(sums({ sales: 0, salesAmount: 0 }), STRINGS)
    expect(document.getElementById("sales")!.hidden).toBe(true)
    expect(document.getElementById("over")!.hidden).toBe(true)
  })

  it("posts one polite status 500 ms after the choices rest, never at load", async () => {
    const dock = await mount()
    dock.render(sums(), STRINGS)
    vi.advanceTimersByTime(STATUS_DELAY * 2)
    expect(text("status")).toBe("")
    dock.render(sums({ now: 50 }), STRINGS)
    dock.render(sums({ now: 60 }), STRINGS)
    vi.advanceTimersByTime(STATUS_DELAY - 1)
    expect(text("status")).toBe("")
    vi.advanceTimersByTime(1)
    expect(text("status")).toBe("You receive 60 PiCoins now.")
  })

  it("reads out a refused validation's line once the table settles", async () => {
    await mount("1 line changed: Pyre. Nothing was sold, listed or entrusted.")
    vi.advanceTimersByTime(STATUS_DELAY)
    expect(text("status")).toBe("1 line changed: Pyre. Nothing was sold, listed or entrusted.")
  })
})
