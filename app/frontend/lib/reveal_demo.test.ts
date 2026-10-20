import { describe, expect, it } from "vitest"
import { CROSSFADE_MS, FLIP_MS, pressRevealDemo, REVEAL_DEMO_START, revealDemoLabel, turnDuration } from "./reveal_demo"

const labels = { reveal: "Reveal", restart: "Start over" }

describe("pressRevealDemo", () => {
  it("reveals the current sample, then turns it back and readies the next", () => {
    const revealed = pressRevealDemo(REVEAL_DEMO_START, 3)
    expect(revealed).toEqual({ revealed: true, index: 0 })

    const back = pressRevealDemo(revealed, 3)
    expect(back).toEqual({ revealed: false, index: 1 })
    expect(pressRevealDemo(back, 3)).toEqual({ revealed: true, index: 1 })
  })

  it("comes back to the first sample after the last", () => {
    expect(pressRevealDemo({ revealed: true, index: 4 }, 5)).toEqual({ revealed: false, index: 0 })
  })

  it("shows the one sample again and again", () => {
    expect(pressRevealDemo({ revealed: true, index: 0 }, 1)).toEqual({ revealed: false, index: 0 })
  })

  it("does nothing without a sample", () => {
    expect(pressRevealDemo(REVEAL_DEMO_START, 0)).toBe(REVEAL_DEMO_START)
  })
})

describe("revealDemoLabel", () => {
  it("reads reveal face down and start over face up", () => {
    expect(revealDemoLabel(REVEAL_DEMO_START, labels)).toBe("Reveal")
    expect(revealDemoLabel({ revealed: true, index: 2 }, labels)).toBe("Start over")
  })
})

describe("turnDuration", () => {
  it("flips in full motion and crossfades under reduced motion", () => {
    expect(turnDuration(false)).toBe(FLIP_MS)
    expect(turnDuration(true)).toBe(CROSSFADE_MS)
  })
})
