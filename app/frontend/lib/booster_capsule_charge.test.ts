// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest"
import { chargeCapsule } from "./booster_capsule_charge"
import { BLAST_AT, fuseTiming } from "./booster_capsule_timeline"

function capsule() {
  const wrap = document.createElement("div")
  const button = document.createElement("button")
  button.className = "booster-canister"
  const glow = document.createElement("span")
  glow.className = "booster-canister__glow"
  wrap.append(button, glow)
  const scanlines = document.createElement("div")
  const calls: Array<{ element: Element; keyframes: Keyframe[]; options: KeyframeAnimationOptions }> = []
  for (const element of [wrap.firstElementChild!, wrap.lastElementChild!, scanlines]) {
    element.animate = vi.fn((keyframes: Keyframe[], options: KeyframeAnimationOptions) => {
      calls.push({ element, keyframes, options })
      return {} as Animation
    }) as unknown as Element["animate"]
  }
  return { wrap, scanlines, calls }
}

// ms from the touch = % × 60 − 780
const percentAt = (ms: number) => (ms + 780) / 60

describe("chargeCapsule", () => {
  it("swells the capsule, beats its glow and surges the scan lines on the fuse's own run", () => {
    const { wrap, scanlines, calls } = capsule()

    const animations = chargeCapsule(wrap, scanlines)

    expect(animations).toHaveLength(3)
    expect(calls.map(({ options }) => options)).toEqual([fuseTiming, fuseTiming, fuseTiming])
  })

  it("is sucked in at the blast, where the fuse holds while the answer is awaited", () => {
    const { wrap, scanlines, calls } = capsule()
    chargeCapsule(wrap, scanlines)

    const swell = calls[0].keyframes
    const atBlast = swell.find((frame) => Math.abs((frame.offset ?? 0) * 100 - percentAt(BLAST_AT)) < 0.001)

    expect(atBlast?.transform).toBe("scale(0.92, 1.07)")
    expect(swell[swell.length - 1].transform).toBe("scale(1, 1)")
  })

  it("does nothing without a capsule", () => {
    expect(chargeCapsule(null, null)).toEqual([])
  })
})
