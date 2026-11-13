// @vitest-environment happy-dom
import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { COUNT_UP_MS } from "../lib/count_up"
import { serverTemplate } from "../lib/server_html"
import EntrustResultController from "./entrust_result_controller"

const MARKUP = `
  <section id="result" data-controller="entrust-result" data-entrust-result-amount-value="12000"
           data-entrust-result-locale-value="en" role="status">
    <h2><span class="picoin-amount" role="img" aria-label="12,000 PiCoins" data-entrust-result-target="amount"><span class="picoin-amount__figure">12,000</span></span></h2>
    <button type="button" data-action="entrust-result#close">Dismiss</button>
  </section>`

let application: Application
let frames: FrameRequestCallback[]

const figure = (): string => document.querySelector(".picoin-amount__figure")!.textContent ?? ""
const label = (): string => document.querySelector(".picoin-amount")!.getAttribute("aria-label") ?? ""
const result = (): HTMLElement => document.getElementById("result")!
const runFrame = (at: number): void => frames.splice(0).forEach((frame) => frame(at))

async function mount(motion: "full" | "reduced"): Promise<void> {
  document.documentElement.dataset.motion = motion
  frames = []
  vi.stubGlobal("requestAnimationFrame", (frame: FrameRequestCallback) => frames.push(frame))
  vi.stubGlobal("cancelAnimationFrame", () => frames.splice(0))
  document.body.replaceChildren(serverTemplate(MARKUP).content)
  application = new Application()
  application.register("entrust-result", EntrustResultController)
  application.start()
  await new Promise((resolve) => setTimeout(resolve, 0))
}

afterEach(() => {
  application.stop()
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.motion
})

describe("the minted amount", () => {
  beforeEach(() => mount("full"))

  it("counts up from zero and lands on the amount, its accessible name fixed throughout", () => {
    expect(figure()).toBe("0")
    runFrame(1000)
    runFrame(1000 + COUNT_UP_MS / 2)
    expect(Number(figure().replace(/,/g, ""))).toBeGreaterThan(0)
    expect(label()).toBe("12,000 PiCoins")
    runFrame(1000 + COUNT_UP_MS)
    expect(figure()).toBe("12,000")
    expect(frames).toHaveLength(0)
  })

  it("shows the amount at once when put away mid-count", () => {
    runFrame(1000)
    const controller = application.getControllerForElementAndIdentifier(result(), "entrust-result")
    ;(controller as EntrustResultController).dismiss()
    expect(figure()).toBe("12,000")
    expect(result().hidden).toBe(true)
  })
})

describe("with reduced motion", () => {
  beforeEach(() => mount("reduced"))

  it("draws the amount as the server wrote it", () => {
    expect(figure()).toBe("12,000")
    expect(frames).toHaveLength(0)
  })
})

describe("closing", () => {
  beforeEach(() => mount("reduced"))

  it("hides the result and tells the screen", () => {
    const heard = vi.fn()
    result().addEventListener("entrust-result:close", heard)
    document.querySelector("button")!.click()
    expect(result().hidden).toBe(true)
    expect(heard).toHaveBeenCalledTimes(1)
  })
})
