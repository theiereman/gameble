// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, describe, expect, it, vi } from "vitest"
import AnnonceController from "./annonce_controller"
import AnnonceDialogController from "./annonce_dialog_controller"
import DialogController from "./dialog_controller"
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
    data-action="annonce-field:typed->annonce#typed annonce-field:entered->annonce#entered annonce-foot:raise->annonce#raise annonce-dialog:confirmed->annonce#confirmed"
    data-annonce-locale-value="en" data-annonce-strings-value="${attr(STRINGS)}"
    data-annonce-annonce-field-outlet="#annonce [data-controller~='annonce-field']"
    data-annonce-annonce-foot-outlet="#annonce [data-controller~='annonce-foot']"
    data-annonce-annonce-status-outlet="#annonce [data-controller~='annonce-status']"
    data-annonce-annonce-dialog-outlet="#annonce [data-controller~='annonce-dialog']">
    <p id="status" data-controller="annonce-status"></p>
    <div id="annonce-bid" data-annonce-target="region">
      <form id="form" data-action="submit->annonce#submit turbo:submit-end->annonce#submitted">
        <div data-controller="annonce-field" data-annonce-field-minimum-value="20000" data-annonce-field-available-value="100000"
          data-annonce-field-buy-now-value="0" data-annonce-field-own-maximum-value="0" data-annonce-field-price-value="20000"
          data-annonce-field-unusual-multiple-value="3" data-annonce-field-answered-value="${answered}">
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
            <button id="buy" type="submit" name="buy_now" value="1">BUY NOW</button>
          </div>
        </div>
      </form>
      <dialog id="unusual" data-controller="dialog annonce-dialog" data-annonce-dialog-kind-value="unusual">
        <h2 tabindex="-1">UNUSUAL</h2>
        <p><span id="unusual-amount" data-annonce-dialog-target="amount"></span> is <span id="unusual-multiple" data-annonce-dialog-target="multiple"></span> times</p>
        <button id="unusual-confirm" type="button" data-action="annonce-dialog#confirm">CONFIRM</button>
        <button id="unusual-cancel" type="button" data-action="dialog#close">CANCEL</button>
      </dialog>
      <dialog id="buy-now" data-controller="dialog annonce-dialog" data-annonce-dialog-kind-value="buy_now">
        <h2 tabindex="-1">BUY NOW</h2>
        <button id="buy-confirm" type="button" data-action="annonce-dialog#confirm">BUY</button>
        <button id="buy-cancel" type="button" data-action="dialog#close">CANCEL</button>
      </dialog>
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
  application.register("annonce-dialog", AnnonceDialogController)
  application.register("dialog", DialogController)
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

function submit(submitter: string = "go"): boolean {
  const event = new SubmitEvent("submit", { bubbles: true, cancelable: true, submitter: el(submitter) })
  el("form").dispatchEvent(event)
  return !event.defaultPrevented
}

function recordRequests(): ReturnType<typeof vi.fn> {
  const requested = vi.fn((submitter?: HTMLElement) => submit(submitter?.id))
  el<HTMLFormElement>("form").requestSubmit = requested as unknown as HTMLFormElement["requestSubmit"]
  return requested
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

describe("the confirmations", () => {
  it("places an ordinary bid in one gesture without a dialog", async () => {
    await mount()
    type("59999")

    expect(submit()).toBe(true)
    expect(el<HTMLDialogElement>("unusual").open).toBe(false)
    expect(el<HTMLDialogElement>("buy-now").open).toBe(false)
  })

  it("asks first for an unusual maximum, writing its amount and truncated multiple", async () => {
    await mount()
    type("79999")

    expect(submit()).toBe(false)
    expect(el<HTMLDialogElement>("unusual").open).toBe(true)
    expect(el("unusual-amount").textContent).toBe("79,999")
    expect(el("unusual-multiple").textContent).toBe("3")
  })

  it("returns to the field with its text unchanged when the dialog is cancelled, and requests nothing", async () => {
    await mount()
    const requested = recordRequests()
    type("60000")
    submit()

    el("unusual-cancel").click()

    expect(el<HTMLDialogElement>("unusual").open).toBe(false)
    expect(document.activeElement).toBe(el("maximum"))
    expect(el<HTMLInputElement>("maximum").value).toBe("60000")
    expect(requested).not.toHaveBeenCalled()
  })

  it("submits once with the same submitter when the unusual maximum is confirmed, and asks again after an edit", async () => {
    await mount()
    const requested = recordRequests()
    type("60000")
    submit()

    el("unusual-confirm").click()
    el("unusual-confirm").click()

    expect(requested).toHaveBeenCalledTimes(1)
    expect(requested.mock.calls[0][0]).toBe(el("go"))
    expect(el<HTMLDialogElement>("unusual").open).toBe(false)

    el("form").dispatchEvent(new Event("turbo:submit-end", { bubbles: true }))
    type("60001")
    expect(submit()).toBe(false)
  })

  it("opens the buy-now confirmation from its button and returns focus to it when cancelled", async () => {
    await mount()
    const requested = recordRequests()

    expect(submit("buy")).toBe(false)
    expect(el<HTMLDialogElement>("buy-now").open).toBe(true)
    expect(el<HTMLDialogElement>("unusual").open).toBe(false)

    el("buy-cancel").click()

    expect(document.activeElement).toBe(el("buy"))
    expect(requested).not.toHaveBeenCalled()
  })

  it("confirms a buy-now through the button that asked, once", async () => {
    await mount()
    const requested = recordRequests()
    submit("buy")

    el("buy-confirm").click()

    expect(requested).toHaveBeenCalledTimes(1)
    expect(requested.mock.calls[0][0]).toBe(el("buy"))
  })
})
