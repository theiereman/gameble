// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DuelController from "./duel_controller"
import { GUARD_MS, RETRY_MS } from "../lib/duel"
import { serverTemplate } from "../lib/server_html"

const BOARD = `
  <section data-controller="duel">
    <p data-duel-target="status"></p>
    <div id="duel-board" data-duel-target="board" data-move-number="1">
      <div id="duel-live" data-duel-target="live">
        <form id="duel-call" data-duel-target="form" data-duel-kind="call" data-duel-sending="Sending…"
          data-action="click->duel#press keydown->duel#keydown keyup->duel#keyup turbo:fetch-request-error->duel#failed turbo:submit-end->duel#ended">
          <input type="hidden" name="resent" value="0" />
          <input type="radio" name="card" value="1" data-action="change->duel#choose" />
          <input type="radio" name="card" value="2" data-action="change->duel#choose" />
          <input type="hidden" name="stat" value="" />
          <input type="hidden" name="direction" value="" />
          <fieldset data-duel-group="call">
            <div data-duel-stat="release">
              <button type="button" data-duel-pick="release:low" aria-pressed="false" data-action="click->duel#pick">Oldest</button>
              <button type="button" data-duel-pick="release:high" aria-pressed="false" data-action="click->duel#pick">Newest</button>
              <span data-duel-card="1" hidden>card 1</span>
              <span data-duel-card="2" hidden>card 2</span>
            </div>
            <div data-duel-stat="rating">
              <button type="button" data-duel-pick="rating:low" aria-pressed="false" aria-disabled="true" data-action="click->duel#pick">Worst</button>
              <button type="button" data-duel-pick="rating:high" aria-pressed="false" aria-disabled="true" data-action="click->duel#pick">Best</button>
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

  const button = (): HTMLElement => document.querySelector("button[type=submit]")!
  const radio = (name: string, value: string, scope: ParentNode = document): HTMLInputElement =>
    scope.querySelector(`input[name=${name}][value=${value}]`)!

  function pick(input: HTMLInputElement): void {
    input.checked = true
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  const side = (value: string): HTMLElement => document.querySelector(`[data-duel-pick='${value}']`)!
  const field = (name: string): string =>
    document.querySelector<HTMLInputElement>(`input[type=hidden][name=${name}]`)!.value

  function chooseAll(): void {
    pick(radio("card", "1"))
    side("release:high").click()
  }

  const escape = (): KeyboardEvent => {
    const event = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
    document.dispatchEvent(event)
    return event
  }

  it("shows the chosen card's reading on every stat, and keeps the button blocked until a card, a stat and a side are chosen", () => {
    expect(document.querySelector<HTMLElement>("[data-duel-card='1']")!.hidden).toBe(true)

    pick(radio("card", "1"))
    expect(document.querySelector<HTMLElement>("[data-duel-card='1']")!.hidden).toBe(false)
    expect(document.querySelector<HTMLElement>("[data-duel-card='2']")!.hidden).toBe(true)
    expect(button().getAttribute("aria-disabled")).toBe("true")

    side("release:low").click()
    expect(side("release:low").getAttribute("aria-pressed")).toBe("true")
    expect(side("release:high").getAttribute("aria-pressed")).toBe("false")
    expect([field("stat"), field("direction")]).toEqual(["release", "low"])
    expect(button().getAttribute("aria-disabled")).toBe("false")

    side("release:high").click()
    expect([field("stat"), field("direction")]).toEqual(["release", "high"])
  })

  it("refuses a stat already called", () => {
    pick(radio("card", "1"))
    side("rating:high").click()

    expect(side("rating:high").getAttribute("aria-pressed")).toBe("false")
    expect([field("stat"), field("direction")]).toEqual(["", ""])
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
    expect(field("direction")).toBe("high")

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

  it("clears the latest choice at each Escape, side then stat then card, and does nothing once none is left", () => {
    chooseAll()

    expect(escape().defaultPrevented).toBe(true)
    expect(field("direction")).toBe("")
    expect(field("stat")).toBe("release")

    escape()
    expect(field("stat")).toBe("")
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
    expect(field("direction")).toBe("high")
  })

  it("reads Sending… on the button after a network failure and sends the same form again until a newer board arrives", () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    chooseAll()
    now += GUARD_MS
    button().click()
    submit.mockClear()

    document.querySelector("form")!.dispatchEvent(new Event("turbo:fetch-request-error", { bubbles: true }))
    expect(button().textContent).toBe("Sending…")
    expect(button().getAttribute("aria-disabled")).toBe("true")

    vi.advanceTimersByTime(RETRY_MS)
    expect(submit).toHaveBeenCalledTimes(1)
    expect(document.querySelector<HTMLInputElement>("input[name=resent]")!.value).toBe("1")
    expect(field("direction")).toBe("high")

    side("release:low").click()
    expect(field("direction")).toBe("high")
    vi.useRealTimers()
  })

  it("also treats a server error response as a move that did not get through, and keeps sending until a board arrives", () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    chooseAll()
    now += GUARD_MS
    button().click()
    submit.mockClear()
    const ended = (detail: object): void => {
      document.querySelector("form")!.dispatchEvent(new CustomEvent("turbo:submit-end", { bubbles: true, detail }))
    }

    ended({ success: false, fetchResponse: { statusCode: 422 } })
    expect(button().textContent).toBe("Call")

    ended({ success: false, fetchResponse: { statusCode: 502 } })
    expect(button().textContent).toBe("Sending…")
    vi.advanceTimersByTime(RETRY_MS * 3)
    expect(submit).toHaveBeenCalledTimes(3)
    vi.useRealTimers()
  })
})
