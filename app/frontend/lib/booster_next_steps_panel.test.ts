// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest"
import { showNextSteps, type NextStepsFrame } from "./booster_next_steps_panel"

const NEXT_STEPS_URL = "/en/booster/next-steps"

function panelWith(hidden: boolean) {
  const panel = document.createElement("section")
  panel.hidden = hidden
  const frame = Object.assign(document.createElement("turbo-frame"), { reload: vi.fn() }) as NextStepsFrame
  panel.append(frame)
  return { panel, frame }
}

describe("showNextSteps", () => {
  it("leaves a panel rendered at load alone, without fetching it again", () => {
    const { panel, frame } = panelWith(false)

    showNextSteps(panel, frame, NEXT_STEPS_URL, true)

    expect(frame.hasAttribute("src")).toBe(false)
    expect(frame.reload).not.toHaveBeenCalled()
  })

  it("loads the frame the first time the reserve runs out", () => {
    const { panel, frame } = panelWith(true)

    showNextSteps(panel, frame, NEXT_STEPS_URL, true)

    expect(panel.hidden).toBe(false)
    expect(frame.getAttribute("src")).toBe(NEXT_STEPS_URL)
  })

  it("hides on a capsule's arrival, and reloads the frame when shown again", () => {
    const { panel, frame } = panelWith(true)
    showNextSteps(panel, frame, NEXT_STEPS_URL, true)

    showNextSteps(panel, frame, NEXT_STEPS_URL, false)
    expect(panel.hidden).toBe(true)
    expect(frame.reload).not.toHaveBeenCalled()

    showNextSteps(panel, frame, NEXT_STEPS_URL, true)
    expect(panel.hidden).toBe(false)
    expect(frame.reload).toHaveBeenCalledOnce()
  })

  it("reloads a frame whose source the load turned absolute", () => {
    const { panel, frame } = panelWith(true)
    frame.setAttribute("src", new URL(NEXT_STEPS_URL, document.baseURI).href)

    showNextSteps(panel, frame, NEXT_STEPS_URL, true)

    expect(frame.reload).toHaveBeenCalledOnce()
  })

  it("asks for the proposals again when a redirect left the frame on another page", () => {
    const { panel, frame } = panelWith(true)
    frame.setAttribute("src", new URL("/en", document.baseURI).href)

    showNextSteps(panel, frame, NEXT_STEPS_URL, true)

    expect(frame.reload).not.toHaveBeenCalled()
    expect(frame.getAttribute("src")).toBe(NEXT_STEPS_URL)
  })
})
