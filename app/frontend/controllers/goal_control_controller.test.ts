// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, describe, expect, it, vi } from "vitest"
import { BOUGHT_GUARD_MS } from "../lib/goal_control"
import { serverTemplate } from "../lib/server_html"
import GoalControlController from "./goal_control_controller"

type StreamRender = (stream: Element) => Promise<void> | void

const markup = (bought: boolean): string => `
  <div id="set-album-goal" data-controller="goal-control" data-action="submit->goal-control#remember"
       ${bought ? 'data-goal-control-bought-value="true"' : ""}>
    <form id="form"><button class="goal-button">Add</button></form>
  </div>`

let application: Application

const mount = async (bought = false): Promise<void> => {
  document.body.replaceChildren(serverTemplate(markup(bought)).content)
  application = new Application()
  application.register("goal-control", GoalControlController)
  application.start()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

const button = (): HTMLButtonElement => document.querySelector<HTMLButtonElement>(".goal-button")!

const submit = (): Event => {
  const event = new Event("submit", { bubbles: true, cancelable: true })
  document.getElementById("form")!.dispatchEvent(event)
  return event
}

const answer = (target: string): { render: StreamRender; stream: Element } => {
  const stream = document.createElement("turbo-stream")
  stream.setAttribute("target", target)
  const detail = { newStream: stream, render: (() => undefined) as StreamRender }
  document.dispatchEvent(new CustomEvent("turbo:before-stream-render", { detail }))
  return { render: detail.render, stream }
}

afterEach(() => {
  vi.restoreAllMocks()
  application.unload("goal-control")
  application.stop()
})

describe("the focus after a goal press", () => {
  it("comes back to the button when a refusal answers with a toast alone, then is forgotten", async () => {
    await mount()
    button().focus()
    submit()
    button().blur()
    const { render, stream } = answer("toasts")
    await render(stream)
    expect(document.activeElement).toBe(button())
    button().blur()
    const later = answer("toasts")
    await later.render(later.stream)
    expect(document.activeElement).not.toBe(button())
  })

  it("ignores a stream aimed elsewhere", async () => {
    await mount()
    button().focus()
    submit()
    button().blur()
    const { render, stream } = answer("bell")
    await render(stream)
    expect(document.activeElement).not.toBe(button())
  })
})

describe("a press right after a slot was bought", () => {
  it("is ignored for a moment, then passes", async () => {
    const now = vi.spyOn(performance, "now").mockReturnValue(1_000)
    await mount(true)
    now.mockReturnValue(1_000 + BOUGHT_GUARD_MS - 1)
    expect(submit().defaultPrevented).toBe(true)
    now.mockReturnValue(1_000 + BOUGHT_GUARD_MS)
    expect(submit().defaultPrevented).toBe(false)
  })
})
