// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { dispatchGameble } from "../lib/events"
import { serverTemplate } from "../lib/server_html"
import EntrustController from "./entrust_controller"
import EntrustRecapController from "./entrust_recap_controller"
import EntrustResultController from "./entrust_result_controller"

const STRINGS = {
  amount: "%{amount} PiCoins",
  quantityLabel: "Copies of %{title}",
  valueText: "%{count} of %{max}",
  max: "of %{max}",
  maxPhone: "/%{max}",
  submit: { one: "Entrust %{count} copy", other: "Entrust %{count} copies", zero: "Entrust" },
  line: "%{title}, season %{season}",
  count: "×%{count}",
  stays: "%{count} stays",
  overCap: "over",
  rareNote: "rare",
  capText: "%{used} of %{cap}",
  status: { one: "%{count} copy, %{amount}", other: "%{count} copies, %{amount}", zero: "0 copies, %{amount}" },
  barCount: { one: "%{count} copy", other: "%{count} copies", zero: "0 copies" },
  more: { one: "and %{count} more", other: "and %{count} more", zero: "" },
}

const attr = (value: unknown): string => JSON.stringify(value).replace(/"/g, "&quot;")

const aside = `
  <aside id="aside" data-entrust-recap-target="aside">
    <p data-entrust-recap-target="prompt"></p>
    <ul data-entrust-recap-target="lines"></ul>
    <template data-entrust-recap-target="lineTemplate"><li class="entrust-recap__line"><span class="entrust-recap__name"></span><span class="entrust-recap__count"></span><span class="entrust-recap__amount"></span><span class="entrust-recap__stays" hidden></span></li></template>
    <template data-entrust-recap-target="amountTemplate"><span class="picoin-amount"><span class="picoin-amount__figure"></span></span></template>
    <template data-entrust-recap-target="stepperTemplate"><div class="entrust-recap__stepper"><span class="stepper"><button class="stepper__button--fewer"></button><span class="stepper__value"></span><button class="stepper__button--more"></button><small class="stepper__max"></small><small class="stepper__max-phone"></small></span></div></template>
    <span class="picoin-amount" data-entrust-recap-target="total"><span class="picoin-amount__figure"></span></span>
    <span class="gauge__segment" data-entrust-recap-target="segment"></span>
    <p data-entrust-recap-target="capText"></p>
    <p data-entrust-recap-target="over" hidden></p>
    <p data-entrust-recap-target="full" hidden></p>
    <p data-entrust-recap-target="rare" hidden></p>
    <p id="sentence" data-entrust-recap-target="sentence"></p>
    <div data-entrust-recap-target="submitSlot"><button type="submit"></button></div>
    <p id="panel-status" data-entrust-recap-target="status"></p>
  </aside>`

// happy-dom reconnects a controller on a <form> whose attributes change, so the root here is a div.
const markup = (inSheet: boolean): string => `
  <div id="entrust" data-layout="wide" data-controller="entrust"
        data-action="entrust-recap:copies->entrust#copies gameble:sheet-shown@window->entrust#sheetShown"
        data-entrust-locale-value="en" data-entrust-cap-left-value="1000000" data-entrust-open-value="true"
        data-entrust-strings-value="${attr(STRINGS)}"
        data-entrust-entrust-recap-outlet="#entrust [data-controller~='entrust-recap']">
    <ul>
      <li data-entrust-target="cell" data-ref="a:1" data-title="A" data-rarity="rare" data-season="1" data-free="2" data-owned="2" data-value="5000" data-ticked="1"></li>
      <li data-entrust-target="cell" data-ref="b:1" data-title="B" data-rarity="rare" data-season="1" data-free="1" data-owned="1" data-value="5000" data-ticked="0"></li>
    </ul>
    <input id="selection" type="hidden" name="selection" value="a:1=1,off:1=2" data-entrust-target="selection">
    <div id="ticks" data-entrust-target="ticks" hidden>
      <span data-ref="a:1" data-title="A" data-rarity="rare" data-season="1" data-free="2" data-owned="2" data-value="5000" data-copies="1"></span>
      <span data-ref="off:1" data-title="Off" data-rarity="common" data-season="1" data-free="3" data-owned="3" data-value="1000" data-copies="2"></span>
    </div>
    <template data-entrust-target="tickTemplate"><span></span></template>
    <div data-controller="entrust-recap" data-entrust-recap-locale-value="en" data-entrust-recap-accessible-value="%{amount} PiCoins">
      <div id="slot" data-entrust-recap-target="slot">${inSheet ? "" : aside}</div>
      <span id="bar-count" data-entrust-recap-target="barCount"></span>
      <span class="picoin-amount" data-entrust-recap-target="barTotal"><span class="picoin-amount__figure"></span></span>
      <dialog id="sheet"><div id="sheet-body" data-entrust-recap-target="sheetBody">${inSheet ? aside : ""}</div></dialog>
      <p id="bar-status" data-entrust-recap-target="barStatus"></p>
    </div>
  </div>`

type Listener = () => void
let phone: boolean
let listeners: Listener[]
let application: Application

function stubMedia(matches: boolean): void {
  phone = matches
  listeners = []
  window.matchMedia = vi.fn(
    () =>
      ({
        get matches() {
          return phone
        },
        addEventListener: (_: string, listener: Listener) => listeners.push(listener),
        removeEventListener: (_: string, listener: Listener) => {
          listeners = listeners.filter((entry) => entry !== listener)
        },
      }) as unknown as MediaQueryList,
  )
}

async function mount(options: { phone: boolean; inSheet?: boolean }): Promise<void> {
  stubMedia(options.phone)
  document.body.replaceChildren(serverTemplate(markup(options.inSheet ?? false)).content)
  application = new Application()
  application.register("entrust", EntrustController)
  application.register("entrust-recap", EntrustRecapController)
  application.start()
  await Promise.resolve()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

const form = (): HTMLElement => document.getElementById("entrust")!
const parentOfAside = (): string | undefined => document.getElementById("aside")!.parentElement?.id
const resize = (matches: boolean): void => {
  phone = matches
  listeners.forEach((listener) => listener())
}
const dialog = (): HTMLDialogElement => document.querySelector("dialog")!
const setSheet = (shown: boolean): void => {
  if (shown) dialog().setAttribute("open", "")
  else dialog().removeAttribute("open")
  dispatchGameble("gameble:sheet-shown", { shown })
}
const ticked = (): string => document.getElementById("bar-count")!.textContent ?? ""

afterEach(() => {
  application.stop()
})

describe("the layout at connect", () => {
  beforeEach(() => mount({ phone: false }))

  it("stays wide with the aside in the slot", () => {
    expect(form().dataset.layout).toBe("wide")
    expect(parentOfAside()).toBe("slot")
  })

  it("draws the bar from the posted ticks, a copy off the loaded pages included", () => {
    expect(ticked()).toBe("3 copies")
  })
})

describe("a phone connect", () => {
  beforeEach(() => mount({ phone: true }))

  it("writes the phone layout and places the aside into the sheet body", () => {
    expect(form().dataset.layout).toBe("phone")
    expect(parentOfAside()).toBe("sheet-body")
  })
})

describe("a restored page", () => {
  it("re-places an aside left in the sheet when the page connects on desktop", async () => {
    await mount({ phone: false, inSheet: true })
    expect(form().dataset.layout).toBe("wide")
    expect(parentOfAside()).toBe("slot")
  })
})

describe("a change while idle", () => {
  beforeEach(() => mount({ phone: false }))

  it("switches at once, moves the recap and keeps the ticks", () => {
    resize(true)
    expect(form().dataset.layout).toBe("phone")
    expect(parentOfAside()).toBe("sheet-body")
    expect(ticked()).toBe("3 copies")
    resize(false)
    expect(form().dataset.layout).toBe("wide")
    expect(parentOfAside()).toBe("slot")
    expect(ticked()).toBe("3 copies")
  })
})

describe("a change while the sheet is open", () => {
  beforeEach(async () => {
    await mount({ phone: true })
    setSheet(true)
  })

  it("is held, then applied once when the sheet closes, the ticks kept", () => {
    resize(false)
    expect(form().dataset.layout).toBe("phone")
    expect(parentOfAside()).toBe("sheet-body")
    setSheet(false)
    expect(form().dataset.layout).toBe("wide")
    expect(parentOfAside()).toBe("slot")
    expect(ticked()).toBe("3 copies")
  })

  it("lets Esc through to the open dialog", () => {
    const event = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    dialog().dispatchEvent(event)
    expect(event.defaultPrevented).toBe(false)
  })
})

describe("the status follows the sheet", () => {
  it("calls refreshStatus when the sheet opens and closes", async () => {
    await mount({ phone: true })
    const recap = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller~='entrust-recap']")!,
      "entrust-recap",
    ) as EntrustRecapController
    const refresh = vi.spyOn(recap, "refreshStatus")
    setSheet(true)
    setSheet(false)
    expect(refresh).toHaveBeenCalledTimes(2)
  })
})

describe("the arrival after a batch", () => {
  const arrival = (): string =>
    markup(false)
      .replace(/<span data-ref[^>]*><\/span>/g, "")
      .replace(
        'data-controller="entrust"',
        `data-controller="entrust" data-entrust-daily-cap-value="1200000" data-entrust-cap-before-value="1100000"
         data-entrust-entrust-result-outlet="#entrust [data-controller~='entrust-result']"`,
      )
      .replace(
        "<ul>",
        '<section id="result" data-controller="entrust-result" data-entrust-result-amount-value="1000000" data-entrust-result-locale-value="en"></section><ul>',
      )

  const root = (): EntrustController =>
    application.getControllerForElementAndIdentifier(form(), "entrust") as EntrustController

  beforeEach(async () => {
    stubMedia(false)
    vi.spyOn(EntrustRecapController.prototype, "growFrom")
    document.body.replaceChildren(serverTemplate(arrival()).content)
    application = new Application()
    application.register("entrust", EntrustController)
    application.register("entrust-recap", EntrustRecapController)
    application.register("entrust-result", EntrustResultController)
    application.start()
    await new Promise((resolve) => setTimeout(resolve, 0))
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it("grows the used part of the cap from what was minted before the batch, once", () => {
    expect(EntrustRecapController.prototype.growFrom).toHaveBeenCalledTimes(1)
    expect(EntrustRecapController.prototype.growFrom).toHaveBeenCalledWith(100000)
  })

  it("puts the result away once a new card is ticked", () => {
    const result = document.getElementById("result")!
    expect(result.hidden).toBe(false)
    root().toggle(new CustomEvent("toggle", { detail: { ref: "a:1" } }))
    expect(result.hidden).toBe(true)
  })
})

describe("the cells and the posted fields", () => {
  const root = (): EntrustController =>
    application.getControllerForElementAndIdentifier(form(), "entrust") as EntrustController
  const posted = (): string => document.querySelector<HTMLInputElement>("#selection")!.value
  const kept = (): string[] =>
    Array.from(document.querySelectorAll<HTMLElement>("#ticks [data-ref]")).map(
      (tick) => `${tick.dataset.ref}=${tick.dataset.copies}`,
    )
  const flush = (): Promise<void> => new Promise((resolve) => setTimeout(resolve, 0))

  beforeEach(() => mount({ phone: false }))

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("posts every tick in one field, in the list's order, and keeps what the recap needs beside it", () => {
    expect(posted()).toBe("a:1=1,off:1=2")
    root().toggle(new CustomEvent("toggle", { detail: { ref: "b:1" } }))
    root().toggle(new CustomEvent("toggle", { detail: { ref: "a:1" } }))
    expect(posted()).toBe("b:1=1,off:1=2")
    expect(kept()).toEqual(["off:1=2", "b:1=1"])
    expect(document.querySelector<HTMLElement>("#ticks [data-ref='b:1']")?.dataset.title).toBe("B")
  })

  it("knows the copies of a page appended later and ticks them", async () => {
    document
      .querySelector("ul")!
      .append(
        serverTemplate(
          '<li data-entrust-target="cell" data-ref="c:1" data-title="C" data-rarity="epic" data-season="1" data-free="1" data-owned="1" data-value="15000" data-ticked="0"></li>',
        ).content,
      )
    await flush()
    root().toggle(new CustomEvent("toggle", { detail: { ref: "c:1" } }))
    expect(posted()).toContain("c:1=1")
  })

  it("ticks every match the server answers, and says so when it cannot answer", async () => {
    const rows = [{ ref: "far:1", title: "Far", rarity: "common", season: 1, free: 1, owned: 1, value: 1000 }]
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify(rows), { status: 200 })),
    )
    await root().selectAll(new CustomEvent("select", { detail: { url: "/matching" } }))
    expect(posted()).toBe("a:1=1,far:1=1,off:1=2")

    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("", { status: 500 })),
    )
    await root().selectAll(new CustomEvent("select", { detail: { url: "/matching" } }))
    expect(posted()).toBe("a:1=1,far:1=1,off:1=2")
  })
})
