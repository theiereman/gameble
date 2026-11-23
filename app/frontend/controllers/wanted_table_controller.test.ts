// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { serverTemplate } from "../lib/server_html"
import WantedTableController, { type WantedStrings } from "./wanted_table_controller"

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
  overCap: { one: "%{count} copy over: %{cards}.", other: "%{count} copies over: %{cards}." },
}

const attr = (value: unknown): string => JSON.stringify(value).replace(/"/g, "&quot;")

const choice = (value: string): string =>
  `<input type="radio" name="lines[0][choice]" value="${value}" data-action="change->wanted-table#choose">`

const MARKUP = `
  <form id="table" data-controller="wanted-table" data-action="keydown.enter->wanted-table#holdEnter"
        data-wanted-table-locale-value="en" data-wanted-table-cap-left-value="12000"
        data-wanted-table-basis-points-value="1000" data-wanted-table-strings-value="${attr(STRINGS)}">
    <table>
      <tbody data-wanted-table-target="line" data-ref="a" data-title="A" data-copies="1" data-value="50"
             data-minimum="78" data-stamp="20" data-average="" data-orders="" data-changed="false">
        <tr><td>
          ${choice("order")}${choice("auction")}${choice("entrust")}
          <div data-wanted-table-target="auction" hidden>
            <input id="start" name="lines[0][starting_price]" data-wanted-table-target="start" data-action="input->wanted-table#typeStart">
          </div>
          <span data-wanted-table-target="receive" hidden><span class="picoin-amount"><span class="picoin-amount__figure"></span></span><span class="wanted-line__when"></span></span>
        </td></tr>
      </tbody>
    </table>
    <button id="all" type="submit" name="all" value="1">ENTRUST ALL ANYWAY</button>
    <dialog id="dialog"></dialog>
  </form>`

let application: Application

const radio = (value: string): HTMLInputElement =>
  document.querySelector<HTMLInputElement>(`input[type="radio"][value="${value}"]`)!

const pick = (value: string): void => {
  radio(value).checked = true
  radio(value).dispatchEvent(new Event("change", { bubbles: true }))
}

const press = (target: Element, key: string): KeyboardEvent => {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })
  target.dispatchEvent(event)
  return event
}

const openPopover = (): void => {
  const query = document.querySelector.bind(document)
  vi.spyOn(document, "querySelector").mockImplementation(((selector: string) =>
    selector.includes(":popover-open") ? document.body : query(selector)) as typeof document.querySelector)
}

beforeEach(async () => {
  document.body.replaceChildren(serverTemplate(MARKUP).content)
  application = new Application()
  application.register("wanted-table", WantedTableController)
  application.start()
  await new Promise((resolve) => setTimeout(resolve, 0))
})

afterEach(() => {
  vi.restoreAllMocks()
  application.unload("wanted-table")
  application.stop()
})

describe("Enter in the wanted table", () => {
  it("never submits from a field, whose form's first button entrusts every line", () => {
    pick("auction")
    expect(press(document.getElementById("start")!, "Enter").defaultPrevented).toBe(true)
  })

  it("still presses a focused button", () => {
    expect(press(document.getElementById("all")!, "Enter").defaultPrevented).toBe(false)
  })
})

describe("Escape in the wanted table", () => {
  it("passes while the choices are the ones the table drew", () => {
    expect(radio("entrust").checked).toBe(true)
    expect(press(document.body, "Escape").defaultPrevented).toBe(false)
  })

  it("is swallowed once a choice moved, so it never drops the choices", () => {
    pick("auction")
    expect(press(document.body, "Escape").defaultPrevented).toBe(true)
  })

  it("reaches an open dialog", () => {
    pick("auction")
    document.getElementById("dialog")!.setAttribute("open", "")
    expect(press(document.getElementById("dialog")!, "Escape").defaultPrevented).toBe(false)
  })

  it("reaches an open popover", () => {
    pick("auction")
    openPopover()
    expect(press(document.body, "Escape").defaultPrevented).toBe(false)
  })
})
