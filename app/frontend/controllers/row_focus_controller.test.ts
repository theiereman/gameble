// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, describe, expect, it } from "vitest"
import RowFocusController from "./row_focus_controller"

const markup = (landing: string | null): string => `
  <main data-controller="row-focus"${landing === null ? "" : ` data-row-focus-landing-value="${landing}"`}>
    <h2 id="heading" tabindex="-1" data-row-focus-target="heading">IN PROGRESS</h2>
    <ul>
      <li><a id="first" href="/a" data-row-token="first">First</a></li>
      <li><a id="second" href="/b" data-row-token="second">Second</a></li>
    </ul>
  </main>`

let application: Application

async function connect(landing: string | null): Promise<void> {
  document.body.innerHTML = markup(landing)
  application = new Application()
  application.register("row-focus", RowFocusController)
  application.start()
  await Promise.resolve()
}

afterEach(() => {
  application.stop()
  document.body.innerHTML = ""
})

describe("RowFocusController", () => {
  it("focuses the title link carrying the landing token", async () => {
    await connect("second")
    expect(document.activeElement?.id).toBe("second")
  })

  it("focuses the group heading when the row is gone", async () => {
    await connect("missing")
    expect(document.activeElement?.id).toBe("heading")
  })

  it("focuses the group heading when the landing is empty", async () => {
    await connect("")
    expect(document.activeElement?.id).toBe("heading")
  })

  it("focuses nothing without a landing", async () => {
    await connect(null)
    expect(document.activeElement).toBe(document.body)
  })
})
