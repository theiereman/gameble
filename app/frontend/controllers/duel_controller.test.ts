// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DuelController from "./duel_controller"
import { GUARD_MS } from "../lib/duel"
import { serverTemplate } from "../lib/server_html"

const BOARD = `
  <section data-controller="duel">
    <p data-duel-target="status"></p>
    <div id="duel-board" data-duel-target="board" data-move-number="1">
      <div id="duel-live" data-duel-target="live">
        <form id="duel-call" data-duel-target="form" data-duel-kind="call"
          data-action="click->duel#press keydown->duel#keydown keyup->duel#keyup">
          <input type="radio" name="card" value="1" data-action="change->duel#choose" />
          <input type="radio" name="card" value="2" data-action="change->duel#choose" />
          <fieldset data-duel-group="stat" hidden>
            <div data-duel-card="1" hidden>
              <input type="radio" name="stat" value="release" disabled data-action="change->duel#choose" />
              <input type="radio" name="stat" value="rating" aria-disabled="true" disabled data-action="change->duel#choose" />
            </div>
            <div data-duel-card="2" hidden>
              <input type="radio" name="stat" value="release" disabled data-action="change->duel#choose" />
              <input type="radio" name="stat" value="rating" aria-disabled="true" disabled data-action="change->duel#choose" />
            </div>
          </fieldset>
          <fieldset data-duel-group="direction" hidden>
            <div data-duel-stat="release" hidden>
              <input type="radio" name="direction" value="high" disabled data-action="change->duel#choose" />
              <input type="radio" name="direction" value="low" disabled data-action="change->duel#choose" />
            </div>
          </fieldset>
          <button type="submit" aria-disabled="true">Call</button>
        </form>
      </div>
    </div>
  </section>`

describe("the duel screen", () => {
  let application: Application
  let now = 0
  const submit = vi.fn()

  beforeEach(async () => {
    now = 1000
    vi.spyOn(performance, "now").mockImplementation(() => now)
    HTMLFormElement.prototype.requestSubmit = submit
    document.body.replaceChildren(serverTemplate(BOARD).content)
    application = Application.start()
    application.register("duel", DuelController)
    await Promise.resolve()
  })

  afterEach(async () => {
    document.body.replaceChildren()
    await Promise.resolve()
    application.stop()
    submit.mockReset()
    vi.restoreAllMocks()
  })

  const button = (): HTMLElement => document.querySelector("button")!
  const radio = (name: string, value: string, scope: ParentNode = document): HTMLInputElement =>
    scope.querySelector(`input[name=${name}][value=${value}]`)!

  function pick(input: HTMLInputElement): void {
    input.checked = true
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  function chooseAll(): void {
    pick(radio("card", "1"))
    pick(radio("stat", "release", document.querySelector("[data-duel-card='1']")!))
    pick(radio("direction", "high"))
  }

  const escape = (): KeyboardEvent => {
    const event = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    document.dispatchEvent(event)
    return event
  }

  it("opens the stats of the chosen card and the directions of the chosen stat, and keeps the button blocked until all three are chosen", () => {
    expect(document.querySelector<HTMLElement>("[data-duel-group=stat]")!.hidden).toBe(true)

    pick(radio("card", "1"))
    expect(document.querySelector<HTMLElement>("[data-duel-group=stat]")!.hidden).toBe(false)
    expect(document.querySelector<HTMLElement>("[data-duel-card='1']")!.hidden).toBe(false)
    expect(document.querySelector<HTMLElement>("[data-duel-card='2']")!.hidden).toBe(true)
    expect(document.querySelector<HTMLInputElement>("[data-duel-card='2'] input")!.disabled).toBe(true)
    expect(button().getAttribute("aria-disabled")).toBe("true")

    pick(radio("stat", "release", document.querySelector("[data-duel-card='1']")!))
    expect(document.querySelector<HTMLElement>("[data-duel-group=direction]")!.hidden).toBe(false)
    expect(radio("direction", "high").disabled).toBe(false)

    pick(radio("direction", "low"))
    expect(button().getAttribute("aria-disabled")).toBe("false")
  })

  it("refuses a stat already called and shows the choices again", () => {
    pick(radio("card", "1"))
    const called = radio("stat", "rating", document.querySelector("[data-duel-card='1']")!)
    pick(called)

    expect(called.checked).toBe(false)
    expect(document.querySelector<HTMLElement>("[data-duel-group=direction]")!.hidden).toBe(true)
  })

  it("fires nothing on a press, on Enter's keydown or on a release inside the guard, and fires on a release after it", () => {
    chooseAll()
    const press = new Event("pointerdown", { bubbles: true })
    button().dispatchEvent(press)
    const enter = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })
    button().dispatchEvent(enter)

    expect(enter.defaultPrevented).toBe(true)
    expect(submit).not.toHaveBeenCalled()

    now += GUARD_MS - 1
    button().click()
    expect(submit).not.toHaveBeenCalled()
    expect(radio("direction", "high").checked).toBe(true)

    now += 1
    button().click()
    expect(submit).toHaveBeenCalledTimes(1)
  })

  it("fires on Enter's keyup once the guard has passed, and never while blocked", () => {
    const enterUp = (): KeyboardEvent => new KeyboardEvent("keyup", { key: "Enter", bubbles: true, cancelable: true })
    button().dispatchEvent(enterUp())
    expect(submit).not.toHaveBeenCalled()

    chooseAll()
    now += GUARD_MS
    button().dispatchEvent(enterUp())
    expect(submit).toHaveBeenCalledTimes(1)
  })

  it("marks the button armed once the guard has elapsed", () => {
    vi.useFakeTimers()
    chooseAll()
    expect(button().hasAttribute("data-armed")).toBe(false)

    vi.advanceTimersByTime(GUARD_MS)
    expect(button().hasAttribute("data-armed")).toBe(true)
    vi.useRealTimers()
  })

  it("clears the latest choice at each Escape, direction then stat then card, and does nothing once none is left", () => {
    chooseAll()

    expect(escape().defaultPrevented).toBe(true)
    expect(radio("direction", "high").checked).toBe(false)
    expect(radio("stat", "release", document.querySelector("[data-duel-card='1']")!).checked).toBe(true)

    escape()
    expect(radio("stat", "release", document.querySelector("[data-duel-card='1']")!).checked).toBe(false)
    expect(radio("card", "1").checked).toBe(true)

    escape()
    expect(radio("card", "1").checked).toBe(false)

    expect(escape().defaultPrevented).toBe(false)
  })

  it("leaves Escape to an open dialog", () => {
    chooseAll()
    const dialog = document.createElement("dialog")
    dialog.setAttribute("open", "")
    document.body.append(dialog)

    expect(escape().defaultPrevented).toBe(false)
    expect(radio("direction", "high").checked).toBe(true)
  })
})
