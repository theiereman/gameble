// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, describe, expect, it, vi } from "vitest"
import OrderFormController from "./order_form_controller"
import { LIVE_DELAY } from "../lib/annonce"
import { serverTemplate } from "../lib/server_html"

const MINIMUMS = { common: 13, uncommon: 34, rare: 78, epic: 223, legendary: 70000 }
const STRINGS = {
  some: "Your price reaches %{reached}. %{next} from %{amount}.",
  all: "Your price reaches every rarity.",
  none: "%{next} from %{amount}.",
  reached: { common: "commons", uncommon: "uncommons", rare: "rares", epic: "epics", legendary: "legendaries" },
  next: { common: "Commons", uncommon: "Uncommons", rare: "Rares", epic: "Epics", legendary: "Legendaries" },
}

const attr = (value: unknown): string => JSON.stringify(value).replace(/"/g, "&quot;")

const markup = (refused: boolean): string => `
  <form id="order-form" data-controller="order-form" data-action="submit->order-form#submit turbo:submit-end->order-form#submitted"
    data-order-form-minimums-value="${attr(MINIMUMS)}" data-order-form-strings-value="${attr(STRINGS)}" data-order-form-locale-value="en">
    <input id="order-price" type="text" data-order-form-target="input" data-action="input->order-form#type keydown->order-form#keydown"
      ${refused ? 'aria-invalid="true" aria-describedby="order-lowest order-error"' : 'aria-describedby="order-lowest"'}>
    <p id="order-error" data-order-form-target="error" ${refused ? "" : "hidden"}>refused</p>
    <ul>
      <li id="chip-common" data-order-form-target="chip" data-rarity="common"><span data-reach="on" hidden>on</span><span data-reach="off">off</span></li>
    </ul>
    <p id="sentence" data-order-form-target="sentence">Commons from 13.</p>
    <p id="status" data-order-form-target="status"></p>
    <span id="held" data-order-form-target="amount">0</span>
    <button id="go" type="submit" data-order-form-target="button">PLACE<span id="go-amount" data-order-form-target="buttonAmount" hidden> · <span data-order-form-target="amount">0</span></span></button>
  </form>`

let application: Application

async function mount(refused = false): Promise<void> {
  document.body.replaceChildren(serverTemplate(markup(refused)).content)
  application = new Application()
  application.register("order-form", OrderFormController)
  application.start()
  await Promise.resolve()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

const el = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T

function type(text: string): void {
  const input = el<HTMLInputElement>("order-price")
  input.value = text
  input.dispatchEvent(new Event("input", { bubbles: true }))
}

function submit(): boolean {
  const event = new SubmitEvent("submit", { bubbles: true, cancelable: true, submitter: el("go") })
  el("order-form").dispatchEvent(event)
  return !event.defaultPrevented
}

afterEach(() => {
  vi.useRealTimers()
  application.stop()
})

describe("typing a price", () => {
  it("redraws the chips, the sentence and the amounts at once, and tells the status only after a pause", async () => {
    await mount()
    vi.useFakeTimers()

    type("100")

    expect(el("chip-common").classList.contains("order-reach__chip--reached")).toBe(true)
    expect(el("sentence").textContent).toBe("Your price reaches commons, uncommons, and rares. Epics from 223.")
    expect(el("held").textContent).toBe("100")
    expect(el("go-amount").hidden).toBe(false)
    expect(el("status").textContent).toBe("")
    vi.advanceTimersByTime(LIVE_DELAY - 1)
    expect(el("status").textContent).toBe("")
    vi.advanceTimersByTime(1)
    expect(el("status").textContent).toBe("Your price reaches commons, uncommons, and rares. Epics from 223.")
  })

  it("hides the refusal and drops aria-invalid once the player types again", async () => {
    await mount(true)

    type("5")

    const input = el<HTMLInputElement>("order-price")
    expect(el("order-error").hidden).toBe(true)
    expect(input.hasAttribute("aria-invalid")).toBe(false)
    expect(input.getAttribute("aria-describedby")).toBe("order-lowest")
  })
})

describe("the keyboard and the button", () => {
  it("moves to the button on Enter without submitting", async () => {
    await mount()
    const submitted = vi.fn((event: Event) => event.preventDefault())
    el("order-form").addEventListener("submit", submitted)

    const enter = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })
    el("order-price").dispatchEvent(enter)

    expect(enter.defaultPrevented).toBe(true)
    expect(document.activeElement).toBe(el("go"))
    expect(submitted).not.toHaveBeenCalled()
  })

  it("lets one submit through per activation, until the request ends", async () => {
    await mount()

    expect(submit()).toBe(true)
    expect(submit()).toBe(false)
    el("order-form").dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true }))
    expect(submit()).toBe(true)
  })
})
