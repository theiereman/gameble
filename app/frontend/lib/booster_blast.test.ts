import { describe, expect, it } from "vitest"
import { screenShakeKeyframes } from "./booster_blast"

const offsets = (frame: Keyframe) => {
  const [, x, y] = /translate\((-?\d+)px, (-?\d+)px\)/.exec(String(frame.transform)) ?? []
  return Math.max(Math.abs(Number(x)), Math.abs(Number(y)))
}

describe("screenShakeKeyframes", () => {
  it("starts and ends still", () => {
    const frames = screenShakeKeyframes(14)
    expect(frames[0].transform).toBe("translate(0px, 0px) rotate(0deg)")
    expect(frames[frames.length - 1].transform).toBe("translate(0px, 0px) rotate(0deg)")
  })

  it("hits hardest first and dies down, within the amplitude", () => {
    const reach = screenShakeKeyframes(14).slice(1, -1).map(offsets)
    expect(Math.max(...reach)).toBeLessThanOrEqual(14)
    expect(reach[0]).toBeGreaterThan(reach[reach.length - 1])
  })

  it("is the same shake every time", () => {
    expect(screenShakeKeyframes(10)).toEqual(screenShakeKeyframes(10))
  })
})
