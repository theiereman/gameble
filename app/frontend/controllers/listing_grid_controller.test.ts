// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { serverTemplate } from "../lib/server_html"
import ListingGridController from "./listing_grid_controller"

const MARKUP = `
  <section data-controller="listing-grid">
    <ul role="listbox" data-action="keydown->listing-grid#keydown">
      <li class="sale-cell" role="option" tabindex="0" aria-selected="false" data-ref="portal:1"
          data-listing-grid-target="cell" data-action="click->listing-grid#choose">Portal</li>
      <li class="sale-cell" role="option" tabindex="-1" aria-selected="false" aria-disabled="true" data-ref="hades:1"
          data-listing-grid-target="cell" data-action="click->listing-grid#choose">Hades</li>
    </ul>
  </section>`

let application: Application
let chosen: string[]

const record = (event: Event): void => {
  chosen.push((event as CustomEvent<{ ref: string }>).detail.ref)
}

const cell = (ref: string): HTMLElement => document.querySelector<HTMLElement>(`[data-ref="${ref}"]`)!
const press = (target: HTMLElement, key: string): void => {
  target.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))
}

beforeEach(async () => {
  chosen = []
  document.body.replaceChildren(serverTemplate(MARKUP).content)
  document.addEventListener("listing-grid:chosen", record)
  application = new Application()
  application.register("listing-grid", ListingGridController)
  application.start()
  await new Promise((resolve) => setTimeout(resolve, 0))
})

afterEach(() => {
  application.stop()
  document.removeEventListener("listing-grid:chosen", record)
})

describe("choosing a cell", () => {
  it("reports a cell with a free copy, clicked or pressed", () => {
    cell("portal:1").click()
    press(cell("portal:1"), "Enter")

    expect(chosen).toEqual(["portal:1", "portal:1"])
  })

  it("ignores a cell with no free copy, clicked or pressed", () => {
    cell("hades:1").click()
    press(cell("hades:1"), " ")

    expect(chosen).toEqual([])
  })
})
