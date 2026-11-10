// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { RecapView } from "../lib/entrust_view"
import EntrustRecapController, { STATUS_DELAY } from "./entrust_recap_controller"

const MARKUP = `
  <section data-controller="entrust-recap" data-entrust-recap-locale-value="en"
           data-entrust-recap-accessible-value="%{amount} PiCoins">
    <input id="search" type="search">
    <p data-entrust-recap-target="prompt">Choose</p>
    <ul data-entrust-recap-target="lines" hidden></ul>
    <template data-entrust-recap-target="lineTemplate">
      <li class="entrust-recap__line"><span class="entrust-recap__name"></span><span class="entrust-recap__count"></span><span class="entrust-recap__amount"></span><span class="entrust-recap__stays" hidden></span></li>
    </template>
    <template data-entrust-recap-target="amountTemplate">
      <span class="picoin-amount" role="img" aria-label="0 PiCoins"><span class="picoin-amount__figure">0</span></span>
    </template>
    <span class="picoin-amount" role="img" data-entrust-recap-target="total"><span class="picoin-amount__figure">0</span></span>
    <div><span class="gauge__segment" data-entrust-recap-target="segment"></span><span class="gauge__segment" data-entrust-recap-target="segment"></span></div>
    <p data-entrust-recap-target="capText"></p>
    <p data-entrust-recap-target="over" hidden></p>
    <p data-entrust-recap-target="full" hidden>Full</p>
    <p id="rare-note" data-entrust-recap-target="rare" hidden></p>
    <p id="not-returned" data-entrust-recap-target="sentence">Not given back.</p>
    <div data-entrust-recap-target="submitSlot"><button type="submit">Entrust</button></div>
    <p role="status" aria-live="polite" data-entrust-recap-target="status"></p>
  </section>`

const view = (over: Partial<RecapView> = {}): RecapView => ({
  prompt: false,
  lines: [{ ref: "rare:1", label: "Rare game, season 1", count: "×1", amount: 5000, stays: null, state: "fits" }],
  received: 5000,
  capUsed: 5000,
  capTotal: 50000,
  capText: "5,000 of 50,000 left",
  full: false,
  over: null,
  rare: null,
  label: "Entrust 2 copies",
  disabled: false,
  status: "2 copies, 5,000 PiCoins",
  ...over,
})

const empty = view({ prompt: true, lines: [], received: 0, capUsed: 0, status: "0 copies, 0 PiCoins" })

let application: Application
let recap: EntrustRecapController

beforeEach(async () => {
  document.body.innerHTML = MARKUP
  application = new Application()
  await application.start()
  application.register("entrust-recap", EntrustRecapController)
  recap = application.getControllerForElementAndIdentifier(
    document.querySelector("section")!,
    "entrust-recap",
  ) as EntrustRecapController
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
  application.stop()
})

const status = (): string => document.querySelector("[role=status]")!.textContent ?? ""

describe("the polite status", () => {
  it("is empty at load, even after the first render", () => {
    expect(status()).toBe("")
    recap.render(empty)
    vi.advanceTimersByTime(STATUS_DELAY * 4)
    expect(status()).toBe("")
  })

  it("posts the count and amount once, after 500 ms without change", () => {
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY - 1)
    expect(status()).toBe("")
    vi.advanceTimersByTime(1)
    expect(status()).toBe("2 copies, 5,000 PiCoins")
  })

  it("posts only the last of rapid changes", () => {
    recap.render(empty)
    recap.render(view({ status: "1 copy, 1,000 PiCoins" }))
    vi.advanceTimersByTime(STATUS_DELAY - 100)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY - 100)
    expect(status()).toBe("")
    vi.advanceTimersByTime(100)
    expect(status()).toBe("2 copies, 5,000 PiCoins")
  })

  it("does not post an unchanged text again", () => {
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
    const region = document.querySelector("[role=status]")!
    const writes: string[] = []
    new MutationObserver(() => writes.push(region.textContent ?? "")).observe(region, {
      childList: true,
      characterData: true,
    })
    recap.render(view())
    recap.render(view({ label: "Entrust 2 copies again" }))
    vi.advanceTimersByTime(STATUS_DELAY * 2)
    expect(writes).toEqual([])
    expect(status()).toBe("2 copies, 5,000 PiCoins")
  })

  it("posts nothing when the selection returns to the posted text before the delay", () => {
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
    recap.render(view({ status: "3 copies, 6,000 PiCoins" }))
    vi.advanceTimersByTime(STATUS_DELAY - 100)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
    expect(status()).toBe("2 copies, 5,000 PiCoins")
  })

  it("never moves the focus", () => {
    const search = document.getElementById("search") as HTMLInputElement
    search.focus()
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
    expect(document.activeElement).toBe(search)
  })
})

describe("the submit button", () => {
  const described = (): string | null => document.querySelector("button")!.getAttribute("aria-describedby")

  it("is described by the not-given-back sentence alone", () => {
    recap.render(view())
    expect(described()).toBe("not-returned")
  })

  it("gains the Rare-or-better note while it is shown and loses it after", () => {
    recap.render(view({ rare: "Note: 1 copy of Rare or better, Rare game." }))
    expect(described()).toBe("not-returned rare-note")
    expect(document.getElementById("rare-note")!.hidden).toBe(false)
    recap.render(view())
    expect(described()).toBe("not-returned")
    expect(document.getElementById("rare-note")!.hidden).toBe(true)
  })

  it("carries the label and the disabled state", () => {
    recap.render(view({ disabled: true, label: "Entrust" }))
    const button = document.querySelector("button")!
    expect([button.textContent, button.disabled]).toEqual(["Entrust", true])
  })
})

describe("the lines", () => {
  it("draws the amount of a line from the server's amount, in its accessible form", () => {
    recap.render(view())
    const amount = document.querySelector(".entrust-recap__line .picoin-amount")!
    expect(amount.getAttribute("aria-label")).toBe("5,000 PiCoins")
    expect(amount.querySelector(".picoin-amount__figure")!.textContent).toBe("5,000")
  })

  it("marks a copy that stays and draws no amount for it", () => {
    recap.render(
      view({ lines: [{ ref: "a:1", label: "A", count: "×1", amount: null, stays: "1 stays", state: "stays" }] }),
    )
    const line = document.querySelector<HTMLElement>(".entrust-recap__line")!
    expect(line.dataset.state).toBe("stays")
    expect(line.querySelector(".picoin-amount")).toBeNull()
    expect(line.querySelector(".entrust-recap__stays")!.textContent).toBe("1 stays")
  })
})
