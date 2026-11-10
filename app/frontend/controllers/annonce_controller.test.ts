// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, describe, expect, it, vi } from "vitest"
import AnnonceController from "./annonce_controller"
import AnnonceFieldController from "./annonce_field_controller"
import AnnonceFootController from "./annonce_foot_controller"
import AnnonceStatusController from "./annonce_status_controller"

const STRINGS = {
  buttonBid: "BID · %{amount}",
  buttonBuy: "BUY · %{amount}",
  buttonIdle: "BID",
  buttonName: "Bid, maximum %{amount} PiCoins",
  buttonRaise: "RAISE · %{amount}",
  liveBuyNow: "Buys at once for %{amount}.",
  liveHold: "%{amount} held.",
  liveRaise: "%{amount} more held.",
}

const attr = (value: unknown): string => JSON.stringify(value).replace(/"/g, "&quot;")

const markup = (answered: boolean): string => `
  <section id="annonce" data-controller="annonce"
    data-action="annonce-field:typed->annonce#typed annonce-field:entered->annonce#entered annonce-foot:raise->annonce#raise"
    data-annonce-locale-value="en" data-annonce-strings-value="${attr(STRINGS)}"
    data-annonce-annonce-field-outlet="#annonce [data-controller~='annonce-field']"
    data-annonce-annonce-foot-outlet="#annonce [data-controller~='annonce-foot']"
    data-annonce-annonce-status-outlet="#annonce [data-controller~='annonce-status']">
    <p id="status" data-controller="annonce-status"></p>
    <div id="annonce-bid" data-annonce-target="region">
      <form id="form" data-action="submit->annonce#submit turbo:submit-end->annonce#submitted">
        <div data-controller="annonce-field" data-annonce-field-minimum-value="20000" data-annonce-field-available-value="100000"
          data-annonce-field-buy-now-value="0" data-annonce-field-own-maximum-value="0" data-annonce-field-answered-value="${answered}">
          <input id="maximum" type="text" data-annonce-field-target="input" data-focus-name="field"
            data-action="input->annonce-field#type keydown->annonce-field#keydown">
          <p id="error" data-annonce-field-target="error" hidden>refused</p>
        </div>
        <div data-controller="annonce-foot">
          <div id="panel" data-annonce-foot-target="panel" ${answered ? "" : "hidden"}>
            <h2 id="heading" tabindex="-1" data-focus-name="heading">answer</h2>
            <button id="raise" type="button" data-action="annonce-foot#raise">raise</button>
          </div>
          <div id="sentences" data-annonce-foot-target="sentences" ${answered ? "hidden" : ""}>
            <p id="live" data-annonce-foot-target="live"></p>
            <button id="go" type="submit" data-annonce-foot-target="button">BID</button>
          </div>
        </div>
      </form>
    </div>
  </section>`

let application: Application

async function mount(answered = false): Promise<void> {
  document.body.innerHTML = markup(answered)
  application = new Application()
  application.register("annonce", AnnonceController)
  application.register("annonce-field", AnnonceFieldController)
  application.register("annonce-foot", AnnonceFootController)
  application.register("annonce-status", AnnonceStatusController)
  application.start()
  await Promise.resolve()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

const el = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T

function type(text: string): void {
  const input = el<HTMLInputElement>("maximum")
  input.value = text
  input.dispatchEvent(new Event("input", { bubbles: true }))
}

function submit(): boolean {
  const event = new Event("submit", { bubbles: true, cancelable: true })
  el("form").dispatchEvent(event)
  return !event.defaultPrevented
}

afterEach(() => {
  vi.useRealTimers()
  application.stop()
})

describe("typing", () => {
  it("names the amount on the button", async () => {
    await mount()
    type("30000")

    expect(el("go").textContent).toBe("BID · 30,000")
    expect(el("go").getAttribute("aria-label")).toBe("Bid, maximum 30,000 PiCoins")
    expect(el("live").textContent).toBe("30,000 held.")
  })

  it("posts the live sentence once to the polite region after the debounce", async () => {
    await mount()
    vi.useFakeTimers()
    type("30000")
    vi.advanceTimersByTime(499)
    expect(el("status").textContent).toBe("")

    vi.advanceTimersByTime(1)
    expect(el("status").textContent).toBe("30,000 held.")

    el("status").textContent = ""
    type("30000")
    vi.advanceTimersByTime(500)
    expect(el("status").textContent).toBe("")
  })

  it("posts nothing for an invalid amount", async () => {
    await mount()
    vi.useFakeTimers()
    type("3x0")
    vi.advanceTimersByTime(600)

    expect(el("status").textContent).toBe("")
  })

  it("clears a refusal on the next edit", async () => {
    await mount()
    el("error").hidden = false
    el("maximum").setAttribute("aria-invalid", "true")
    type("1")

    expect(el("error").hidden).toBe(true)
    expect(el("maximum").hasAttribute("aria-invalid")).toBe(false)
  })

  it("shows the foot again on the first keystroke after an answer", async () => {
    await mount(true)
    expect(el("sentences").hidden).toBe(true)
    expect(el("panel").hidden).toBe(false)

    type("1")

    expect(el("sentences").hidden).toBe(false)
    expect(el("panel").hidden).toBe(true)
  })
})

describe("Enter and the single submission", () => {
  it("moves focus to the button on Enter and submits nothing", async () => {
    await mount()
    const submitted = vi.fn()
    el("form").addEventListener("submit", submitted)
    type("30000")

    const enter = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })
    el("maximum").dispatchEvent(enter)

    expect(enter.defaultPrevented).toBe(true)
    expect(document.activeElement).toBe(el("go"))
    expect(submitted).not.toHaveBeenCalled()
  })

  it("lets a first submit through and cancels a second until the submission ends", async () => {
    await mount()

    expect(submit()).toBe(true)
    expect(submit()).toBe(false)

    el("form").dispatchEvent(new Event("turbo:submit-end", { bubbles: true }))
    expect(submit()).toBe(true)
  })
})

describe("the answer panel", () => {
  it("focuses the field when the raise action is pressed", async () => {
    await mount(true)
    el("raise").click()

    expect(document.activeElement).toBe(el("maximum"))
  })

  it("focuses what the server asked for when the region connects", async () => {
    await mount()
    const region = el("annonce-bid")
    region.dataset.focus = "heading"
    const replacement = region.cloneNode(true) as HTMLElement
    replacement.dataset.focus = "heading"
    region.replaceWith(replacement)
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(document.activeElement?.id).toBe("heading")
  })
})
