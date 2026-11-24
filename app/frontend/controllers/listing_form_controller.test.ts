// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { serverTemplate } from "../lib/server_html"
import ListingFieldsController from "./listing_fields_controller"
import ListingFormController from "./listing_form_controller"
import ListingSummaryController from "./listing_summary_controller"

const STRINGS = JSON.stringify({
  amount: "%{amount} PiCoins",
  invalidPrice: "Enter a whole number of PiCoins, above zero.",
  minimumHint: "At least %{amount} for a %{rarity}",
  minimumRefusal: "At least %{amount} for a %{rarity}.",
  opening: "With these orders, the auction starts at %{amount}, led by a buy order.",
  orderLeft: "The order at %{amount} stays open.",
  orderWaiting: "A buy order is waiting for you: %{amount} PiCoins",
  stampShort: "You are short of %{amount} PiCoins for the stamp.",
  status: "You receive %{amount} PiCoins",
  step: "Step %{step} of 2",
}).replaceAll('"', "&quot;")

const cell = (ref: string, order: string, orders = ""): string => `
  <div data-listing-form-target="cell" data-ref="${ref}" data-title="${ref}" data-rarity="rare" data-rarity-name="rare" data-season="1"
      data-free="1" data-minimum="78" data-stamp="20" data-order="${order}" data-orders="${orders}"></div>
  ${orders ? `<template data-listing-form-target="ordersTemplate" data-ref="${ref}"><p class="sale-orders">2 buy orders</p></template>` : ""}
  <template data-listing-form-target="orderTemplate" data-ref="${ref}">${order ? `<button type="submit" name="order" value="t-${ref}">SELL NOW</button>` : `<p class="sale-order-none">No buy order for this card.</p>`}</template>`

// A div stands for the form: happy-dom hands Stimulus a proxied form element its targets never match.
const markup = (refused: boolean): string => `
  <div id="listing-form" data-controller="listing-form" data-action="submit->listing-form#submit"
      data-listing-form-locale-value="en" data-listing-form-basis-points-value="1000" data-listing-form-increment-value="500" data-listing-form-open-value="true"
      data-listing-form-available-value="500" data-listing-form-strings-value="${STRINGS}"
      data-listing-form-listing-fields-outlet="#listing-form [data-controller~='listing-fields']"
      data-listing-form-listing-summary-outlet="#listing-form [data-controller~='listing-summary']">
    <input type="hidden" name="ref" value="${refused ? "alpha:1" : ""}" data-listing-form-target="ref">
    ${cell("alpha:1", "900", "400,300")}${cell("beta:1", "")}
    <div class="sale-fields" data-controller="listing-fields">
      <div data-listing-fields-target="orderSlot" data-ref="${refused ? "alpha:1" : ""}">${refused ? `<p role="alert" tabindex="-1" data-listing-fields-target="orderRefusal">Changed.</p><button type="submit" name="order" value="t-alpha:1">SELL NOW</button>` : ""}</div>
      <input name="starting_price" value="" data-listing-fields-target="start" data-listing-form-target="start">
      <div data-listing-fields-target="ordersSlot" data-ref=""></div>
      <p data-listing-fields-target="hint"></p>
      <p data-listing-fields-target="openingLine" hidden></p>
      <p data-listing-fields-target="leftLine" hidden></p>
      <p id="sale-start-error" data-listing-fields-target="startError" hidden></p>
      <p data-listing-fields-target="durationError" hidden></p>
    </div>
    <div data-controller="listing-summary" data-listing-summary-locale-value="en" data-listing-summary-accessible-value="%{amount} PiCoins">
      <span data-listing-summary-target="stampLine"></span><span data-listing-summary-target="stamp"></span>
      <p data-listing-summary-target="short" hidden><span data-listing-summary-target="shortText"></span></p>
      <span data-listing-summary-target="commission"></span><span data-listing-summary-target="received"></span>
      <button type="submit" class="button button--primary">PUT UP FOR SALE <span data-listing-summary-target="submitStamp"></span></button>
      <p data-listing-summary-target="status"></p>
    </div>
  </div>`

let application: Application

async function mount(refused = false): Promise<void> {
  document.body.replaceChildren(serverTemplate(markup(refused)).content)
  application = new Application()
  application.register("listing-form", ListingFormController)
  application.register("listing-fields", ListingFieldsController)
  application.register("listing-summary", ListingSummaryController)
  application.start()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

const form = (): ListingFormController =>
  application.getControllerForElementAndIdentifier(
    document.querySelector("#listing-form")!,
    "listing-form",
  ) as ListingFormController
const slot = (): HTMLElement => document.querySelector<HTMLElement>("[data-listing-fields-target=orderSlot]")!
const target = (name: string): HTMLElement =>
  document.querySelector<HTMLElement>(`[data-listing-fields-target=${name}]`)!
const listButton = (): HTMLElement => document.querySelector<HTMLElement>("[data-controller=listing-summary] button")!

function submitWith(submitter: HTMLElement): Event {
  const event = new Event("submit", { cancelable: true, bubbles: true })
  Object.defineProperty(event, "submitter", { value: submitter })
  document.querySelector("#listing-form")!.dispatchEvent(event)
  return event
}

afterEach(() => {
  application.stop()
})

describe("the best-order banner", () => {
  beforeEach(() => mount())

  it("follows the choice, the listing button turning secondary while an order waits", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "alpha:1" } }))
    expect(slot().querySelector("button[name=order]")?.getAttribute("value")).toBe("t-alpha:1")
    expect(listButton().classList.contains("button--secondary")).toBe(true)

    form().chosen(new CustomEvent("chosen", { detail: { ref: "beta:1" } }))
    expect(slot().textContent).toContain("No buy order for this card.")
    expect(listButton().classList.contains("button--primary")).toBe(true)
  })

  it("sells without the starting price and only once", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "alpha:1" } }))
    const sell = slot().querySelector<HTMLElement>("button[name=order]")!

    expect(submitWith(sell).defaultPrevented).toBe(false)
    expect(submitWith(sell).defaultPrevented).toBe(true)
    expect(document.querySelector("#sale-start-error")?.hasAttribute("hidden")).toBe(true)
  })

  it("sells again once the page is shown from the back-forward cache", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "alpha:1" } }))
    const sell = slot().querySelector<HTMLElement>("button[name=order]")!
    submitWith(sell)

    window.dispatchEvent(new Event("pageshow"))

    expect(submitWith(sell).defaultPrevented).toBe(false)
  })

  it("still validates the starting price for the listing button", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "beta:1" } }))

    expect(submitWith(listButton()).defaultPrevented).toBe(true)
  })
})

describe("orders turning into bids", () => {
  beforeEach(() => mount())

  it("draws the orders block, prefills the start at the lowest order and says where the auction starts", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "alpha:1" } }))

    expect(target("ordersSlot").textContent).toBe("2 buy orders")
    expect((target("start") as HTMLInputElement).value).toBe("300")
    expect(target("openingLine").textContent).toBe("With these orders, the auction starts at 315, led by a buy order.")
    expect(target("leftLine").hidden).toBe(true)
  })

  it("follows the typed start and names the orders it leaves open", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "alpha:1" } }))
    const input = target("start") as HTMLInputElement
    input.value = "350"
    input.dispatchEvent(new Event("input", { bubbles: true }))
    form().typed(new CustomEvent("typed", { detail: { field: "start", value: "350" } }))

    expect(target("openingLine").textContent).toBe("With these orders, the auction starts at 350, led by a buy order.")
    expect(target("leftLine").textContent).toBe("The order at 300 stays open.")
  })

  it("says nothing for an edition without orders", () => {
    form().chosen(new CustomEvent("chosen", { detail: { ref: "beta:1" } }))

    expect(target("ordersSlot").textContent).toBe("")
    expect((target("start") as HTMLInputElement).value).toBe("")
    expect(target("openingLine").hidden).toBe(true)
  })
})

describe("a refused sale", () => {
  beforeEach(() => mount(true))

  it("keeps the server's banner and focuses its sentence", () => {
    expect(document.activeElement?.textContent).toBe("Changed.")
    expect(slot().querySelector("[role=alert]")).not.toBeNull()
  })
})
