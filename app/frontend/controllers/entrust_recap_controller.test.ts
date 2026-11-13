// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { LineView, RecapView } from "../lib/entrust_view"
import EntrustRecapController, { GROW_HOLD, GROW_STEP, STATUS_DELAY } from "./entrust_recap_controller"
import { serverTemplate } from "../lib/server_html"

const MARKUP = `
  <form id="entrust">
  <div id="wrapper" data-controller="entrust-recap" data-entrust-recap-locale-value="en"
       data-entrust-recap-accessible-value="%{amount} PiCoins">
    <input id="search" type="search">
    <div data-entrust-recap-target="slot">
    <aside data-entrust-recap-target="aside">
    <p data-entrust-recap-target="prompt">Choose</p>
    <ul data-entrust-recap-target="lines" hidden></ul>
    <template data-entrust-recap-target="lineTemplate">
      <li class="entrust-recap__line"><span class="entrust-recap__name"></span><span class="entrust-recap__count"></span><span class="entrust-recap__amount"></span><span class="entrust-recap__stays" hidden></span></li>
    </template>
    <template data-entrust-recap-target="amountTemplate">
      <span class="picoin-amount" role="img" aria-label="0 PiCoins"><span class="picoin-amount__figure">0</span></span>
    </template>
    <template data-entrust-recap-target="stepperTemplate">
      <div class="entrust-recap__stepper"><span class="stepper" role="spinbutton" tabindex="0" aria-valuenow="1" aria-valuemax="2" data-action="keydown->entrust-recap#stepperKey"><button type="button" class="stepper__button stepper__button--fewer" data-step="-1" data-action="mousedown->entrust-recap#keepFocus click->entrust-recap#step">-</button><span class="stepper__value">x1</span><button type="button" class="stepper__button stepper__button--more" data-step="1" data-action="mousedown->entrust-recap#keepFocus click->entrust-recap#step">+</button><small class="stepper__max"></small><small class="stepper__max-phone"></small></span></div>
    </template>
    <span class="picoin-amount" role="img" data-entrust-recap-target="total"><span class="picoin-amount__figure">0</span></span>
    <div><span class="gauge__segment" data-entrust-recap-target="segment"></span><span class="gauge__segment" data-entrust-recap-target="segment"></span></div>
    <p data-entrust-recap-target="capText"></p>
    <p data-entrust-recap-target="over" hidden></p>
    <p data-entrust-recap-target="full" hidden>Full</p>
    <p id="rare-note" data-entrust-recap-target="rare" hidden></p>
    <p id="not-returned" data-entrust-recap-target="sentence">Not given back.</p>
    <div data-entrust-recap-target="submitSlot"><button type="submit">Entrust</button></div>
    <p id="panel-status" role="status" aria-live="polite" data-entrust-recap-target="status"></p>
    </aside>
    </div>
    <div role="group">
      <span id="bar-count" data-entrust-recap-target="barCount"></span>
      <span id="bar-total" class="picoin-amount" role="img" data-entrust-recap-target="barTotal"><span class="picoin-amount__figure">0</span></span>
    </div>
    <dialog id="sheet"><div id="sheet-body" data-entrust-recap-target="sheetBody"></div></dialog>
    <p id="bar-status" role="status" aria-live="polite" data-entrust-recap-target="barStatus"></p>
  </div>
  </form>`

const view = (over: Partial<RecapView> = {}): RecapView => ({
  prompt: false,
  lines: [
    {
      ref: "rare:1",
      label: "Rare game, season 1",
      count: "×1",
      amount: 5000,
      stays: null,
      stepper: null,
      state: "fits",
    },
  ],
  received: 5000,
  capBefore: 0,
  capUsed: 5000,
  capTotal: 50000,
  capText: "5,000 of 50,000 today",
  full: false,
  over: null,
  rare: null,
  more: null,
  label: "Entrust 2 copies",
  disabled: false,
  status: "2 copies, 5,000 PiCoins",
  bar: { count: "2 copies", amount: 5000 },
  ...over,
})

const empty = view({ prompt: true, lines: [], received: 0, capUsed: 0, status: "0 copies, 0 PiCoins" })

let application: Application
let recap: EntrustRecapController

beforeEach(async () => {
  document.body.replaceChildren(serverTemplate(MARKUP).content)
  application = new Application()
  await application.start()
  application.register("entrust-recap", EntrustRecapController)
  recap = application.getControllerForElementAndIdentifier(
    document.getElementById("wrapper")!,
    "entrust-recap",
  ) as EntrustRecapController
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
  application.stop()
})

const status = (): string => document.getElementById("panel-status")!.textContent ?? ""
const barStatus = (): string => document.getElementById("bar-status")!.textContent ?? ""

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
    const region = document.getElementById("panel-status")!
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

  it("keeps the reason id after the notes while the reason is on the page", () => {
    document.body.append(serverTemplate('<div id="reason"></div>').content)
    document.getElementById("wrapper")!.dataset.entrustRecapReasonIdValue = "reason"
    recap.render(view())
    expect(described()).toBe("not-returned reason")
    recap.render(view({ rare: "Note: 1 copy of Rare or better, Rare game." }))
    expect(described()).toBe("not-returned rare-note reason")
  })

  it("leaves out a reason id that is not on the page", () => {
    document.getElementById("wrapper")!.dataset.entrustRecapReasonIdValue = "missing"
    recap.render(view())
    expect(described()).toBe("not-returned")
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
      view({
        lines: [{ ref: "a:1", label: "A", count: "×1", amount: null, stays: "1 stays", stepper: null, state: "stays" }],
      }),
    )
    const line = document.querySelector<HTMLElement>(".entrust-recap__line")!
    expect(line.dataset.state).toBe("stays")
    expect(line.querySelector(".picoin-amount")).toBeNull()
    expect(line.querySelector(".entrust-recap__stays")!.textContent).toBe("1 stays")
  })
})

const spin = (value: number, max = 3) => ({
  value,
  max,
  label: "Copies",
  valueText: `${value} of ${max}`,
  maxText: `of ${max}`,
  maxPhoneText: `/${max}`,
})

const line = (ref: string, over: Partial<LineView> = {}): LineView => ({
  ref,
  label: `Game ${ref}`,
  count: "×1",
  amount: 1000,
  stays: null,
  stepper: spin(1),
  state: "fits",
  ...over,
})

const refs = (): (string | undefined)[] =>
  Array.from(document.querySelectorAll<HTMLElement>(".entrust-recap__line")).map((item) => item.dataset.ref)

const actionsBound = async (): Promise<void> => {
  await Promise.resolve()
  await Promise.resolve()
}

const dialog = (): HTMLDialogElement => document.querySelector("dialog")!

describe("the line steppers", () => {
  it("sends the copies of the line whose plus is pressed", async () => {
    const seen: unknown[] = []
    document.addEventListener("entrust-recap:copies", (event) => seen.push((event as CustomEvent).detail))
    recap.render(view({ lines: [line("a:1"), line("b:1")] }))
    await actionsBound()
    document.querySelectorAll<HTMLElement>(".stepper__button--more")[1]!.click()
    expect(seen).toEqual([{ ref: "b:1", copies: 2 }])
  })

  it("prevents the default of a mousedown on a button so the stepper keeps its focus", async () => {
    recap.render(view({ lines: [line("a:1")] }))
    await actionsBound()
    const event = new MouseEvent("mousedown", { bubbles: true, cancelable: true })
    document.querySelector(".stepper__button--more")!.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)
  })

  it("is absent for a line with a single free copy and reflects the view otherwise", () => {
    recap.render(view({ lines: [line("a:1", { stepper: null }), line("b:1", { stepper: spin(2) })] }))
    const items = document.querySelectorAll(".entrust-recap__line")
    expect(items[0]!.querySelector(".stepper")).toBeNull()
    expect(items[1]!.querySelector(".stepper")!.getAttribute("aria-valuenow")).toBe("2")
    recap.render(view({ lines: [line("a:1", { stepper: null }), line("b:1", { stepper: null })] }))
    expect(document.querySelector(".stepper")).toBeNull()
  })

  it("keeps the focus on the same stepper across a re-render", () => {
    recap.render(view({ lines: [line("a:1")] }))
    const stepper = document.querySelector<HTMLElement>(".stepper")!
    stepper.focus()
    recap.render(view({ lines: [line("a:1", { stepper: spin(2) })] }))
    expect(document.querySelector(".stepper")).toBe(stepper)
    expect(document.activeElement).toBe(stepper)
  })
})

describe("the line reconcile", () => {
  it("reuses the line element after a re-render", () => {
    recap.render(view({ lines: [line("a:1")] }))
    const first = document.querySelector(".entrust-recap__line")
    recap.render(view({ lines: [line("a:1", { count: "×2" })] }))
    expect(document.querySelector(".entrust-recap__line")).toBe(first)
    expect(first!.querySelector(".entrust-recap__count")!.textContent).toBe("×2")
  })

  it("inserts a more valuable line on top while another stepper holds the focus", () => {
    recap.render(view({ lines: [line("b:1"), line("c:1")] }))
    const stepper = document.querySelectorAll<HTMLElement>(".stepper")[1]!
    stepper.focus()
    recap.render(view({ lines: [line("a:1"), line("b:1"), line("c:1")] }))
    expect(refs()).toEqual(["a:1", "b:1", "c:1"])
    expect(document.querySelectorAll(".stepper")[2]).toBe(stepper)
    expect(document.activeElement).toBe(stepper)
  })

  it("appends a last line and removes a stale one", () => {
    recap.render(view({ lines: [line("a:1"), line("b:1")] }))
    recap.render(view({ lines: [line("b:1"), line("c:1")] }))
    expect(refs()).toEqual(["b:1", "c:1"])
  })

  it("touches no node when the order is unchanged", () => {
    recap.render(view({ lines: [line("a:1"), line("b:1")] }))
    const list = document.querySelector("ul")!
    const records: MutationRecord[] = []
    const observer = new MutationObserver((batch) => records.push(...batch))
    observer.observe(list, { childList: true })
    recap.render(view({ lines: [line("a:1", { count: "×2" }), line("b:1")] }))
    return Promise.resolve().then(() => {
      observer.disconnect()
      expect(records).toEqual([])
    })
  })

  it("moves only the line out of place when the order changes", async () => {
    recap.render(view({ lines: [line("a:1"), line("b:1"), line("c:1")] }))
    const [a, b] = Array.from(document.querySelectorAll(".entrust-recap__line"))
    const moved: Node[] = []
    const observer = new MutationObserver((batch) => batch.forEach((r) => moved.push(...r.addedNodes)))
    observer.observe(document.querySelector("ul")!, { childList: true })
    recap.render(view({ lines: [line("c:1"), line("a:1"), line("b:1")] }))
    await Promise.resolve()
    observer.disconnect()
    expect(refs()).toEqual(["c:1", "a:1", "b:1"])
    expect(moved).toHaveLength(1)
    expect(moved).not.toContain(a)
    expect(moved).not.toContain(b)
  })
})

describe("the bar", () => {
  it("shows the count and the exact total", () => {
    recap.render(view({ bar: { count: "3 copies", amount: 12345 } }))
    expect(document.getElementById("bar-count")!.textContent).toBe("3 copies")
    const total = document.getElementById("bar-total")!
    expect(total.getAttribute("aria-label")).toBe("12,345 PiCoins")
    expect(total.querySelector(".picoin-amount__figure")!.textContent).toBe("12,345")
  })
})

describe("the placement", () => {
  it("moves the aside into the sheet body and back, the submit staying in the form", () => {
    const aside = document.querySelector("aside")!
    recap.place("phone")
    expect(aside.parentElement).toBe(document.getElementById("sheet-body"))
    expect(recap.placedIn()).toBe("sheet")
    expect(document.getElementById("entrust")!.contains(document.querySelector("button[type=submit]"))).toBe(true)
    recap.place("wide")
    expect(aside.parentElement).toBe(document.querySelector("[data-entrust-recap-target=slot]"))
    expect(recap.placedIn()).toBe("slot")
  })

  it("reads whether the sheet is open from its dialog", () => {
    expect(recap.sheetIsOpen()).toBe(false)
    dialog().setAttribute("open", "")
    expect(recap.sheetIsOpen()).toBe(true)
  })

  it("keeps the polite status working once the panel moved", () => {
    recap.place("wide")
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
    expect(status()).toBe("2 copies, 5,000 PiCoins")
  })
})

describe("the two status lines", () => {
  const post = (): void => {
    recap.render(empty)
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY)
  }

  it("writes the panel line alone in the wide layout", () => {
    post()
    expect([status(), barStatus()]).toEqual(["2 copies, 5,000 PiCoins", ""])
  })

  it("writes the bar line alone on the phone with the sheet closed", () => {
    recap.place("phone")
    post()
    expect([status(), barStatus()]).toEqual(["", "2 copies, 5,000 PiCoins"])
  })

  it("writes the panel line alone on the phone with the sheet open", () => {
    recap.place("phone")
    dialog().setAttribute("open", "")
    post()
    expect([status(), barStatus()]).toEqual(["2 copies, 5,000 PiCoins", ""])
  })

  it("moves the posted text to the line that applies when the sheet opens and closes", () => {
    recap.place("phone")
    post()
    dialog().setAttribute("open", "")
    recap.refreshStatus()
    expect([status(), barStatus()]).toEqual(["2 copies, 5,000 PiCoins", ""])
    dialog().removeAttribute("open")
    recap.refreshStatus()
    expect([status(), barStatus()]).toEqual(["", "2 copies, 5,000 PiCoins"])
  })

  it("does nothing on refresh before anything was posted", () => {
    recap.refreshStatus()
    expect([status(), barStatus()]).toEqual(["", ""])
  })

  it("still drops a repeat of the same text after a refresh", () => {
    recap.place("phone")
    post()
    recap.refreshStatus()
    recap.render(view())
    vi.advanceTimersByTime(STATUS_DELAY * 2)
    expect(barStatus()).toBe("2 copies, 5,000 PiCoins")
  })
})

describe("the daily cap gauge", () => {
  const lit = (): number => document.querySelectorAll(".gauge__segment--lit").length
  const selected = (): number => document.querySelectorAll(".gauge__segment--selected").length
  const fresh = (): number => document.querySelectorAll(".gauge__segment--fresh").length
  const gauge = (): HTMLElement => document.querySelector<HTMLElement>(".gauge__segment")!.parentElement!

  afterEach(() => {
    delete document.documentElement.dataset.motion
  })

  it("lights what was minted earlier today in one shade and the selection in another", () => {
    recap.render(view({ capBefore: 25000, capUsed: 50000 }))
    expect(lit()).toBe(2)
    expect(selected()).toBe(1)
    recap.render(view({ capBefore: 25000, capUsed: 25000 }))
    expect(lit()).toBe(1)
    expect(selected()).toBe(0)
  })

  describe("after a batch", () => {
    beforeEach(() => {
      document.documentElement.dataset.motion = "full"
      recap.render(view({ capBefore: 50000, capUsed: 50000 }))
    })

    it("holds the earlier reading, then grows the used part one segment at a time in a fresh shade", () => {
      recap.growFrom(0)
      expect(lit()).toBe(0)
      expect(gauge().hasAttribute("data-growing")).toBe(true)

      vi.advanceTimersByTime(GROW_HOLD)
      expect(lit()).toBe(1)
      expect(fresh()).toBe(1)
      vi.advanceTimersByTime(GROW_STEP)
      expect(lit()).toBe(2)
      expect(fresh()).toBe(0)
      expect(selected()).toBe(0)
      expect(gauge().hasAttribute("data-growing")).toBe(false)
    })

    it("keeps growing through a render that lands on the same reading", () => {
      recap.growFrom(0)
      recap.render(view({ capBefore: 50000, capUsed: 50000 }))
      expect(lit()).toBe(0)
    })

    it("jumps to a new reading when the player ticks mid-growth", () => {
      recap.growFrom(0)
      recap.render(view({ capBefore: 25000, capUsed: 50000 }))
      expect(lit()).toBe(2)
      expect(selected()).toBe(1)
      expect(gauge().hasAttribute("data-growing")).toBe(false)
    })

    it("shows the new reading at once when motion is reduced", () => {
      document.documentElement.dataset.motion = "reduced"
      recap.growFrom(0)
      expect(lit()).toBe(2)
      expect(gauge().hasAttribute("data-growing")).toBe(false)
    })
  })
})
