// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import UnfoldController from "./unfold_controller"
import { serverTemplate } from "../lib/server_html"

describe("the unfold button", () => {
  let application: Application

  beforeEach(async () => {
    document.body.replaceChildren(
      serverTemplate(`
      <section data-controller="unfold">
        <button type="button" data-unfold-target="button" data-action="unfold#show">See</button>
        <div hidden tabindex="-1" data-unfold-target="content">The rest</div>
      </section>`).content,
    )
    application = Application.start()
    application.register("unfold", UnfoldController)
    await Promise.resolve()
  })

  afterEach(() => application.stop())

  it("shows the rest, hides itself and moves focus to the rest", () => {
    document.querySelector<HTMLButtonElement>("button")!.click()

    const content = document.querySelector<HTMLElement>("[data-unfold-target=content]")!
    expect(content.hidden).toBe(false)
    expect(document.querySelector<HTMLButtonElement>("button")!.hidden).toBe(true)
    expect(document.activeElement).toBe(content)
  })
})
