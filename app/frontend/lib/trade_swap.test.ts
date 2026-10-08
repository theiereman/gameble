import { describe, expect, it } from "vitest"
import { SWAP_LANDING, SWAP_LIFT, confettiDirections, swapKeyframes, swapPath } from "./trade_swap"

describe("swapPath", () => {
  it("starts at the offset and ends at the resting place", () => {
    const path = swapPath({ x: 300, y: 0 })
    expect(path[0]).toEqual({ x: 300, y: 0 })
    expect(path[path.length - 1]).toEqual({ x: 0, y: 0 })
  })

  it("arcs over the strip for a card coming from the right, under it for one from the left", () => {
    const fromRight = swapPath({ x: 300, y: 0 })
    const fromLeft = swapPath({ x: -300, y: 0 })
    const middle = Math.floor(fromRight.length / 2)
    expect(fromRight[middle].y).toBeLessThan(-SWAP_LIFT / 4)
    expect(fromLeft[middle].y).toBeGreaterThan(SWAP_LIFT / 4)
  })

  it("passes the two columns of a stacked board on either side", () => {
    const fromBelow = swapPath({ x: 0, y: 400 })
    const fromAbove = swapPath({ x: 0, y: -400 })
    const middle = Math.floor(fromBelow.length / 2)
    expect(fromBelow[middle].x).toBeGreaterThan(0)
    expect(fromAbove[middle].x).toBeLessThan(0)
  })

  it("stays put without an offset", () => {
    expect(swapPath({ x: 0, y: 0 }).every((point) => point.x === 0 && point.y === 0)).toBe(true)
  })
})

describe("swapKeyframes", () => {
  it("flies until the landing, then squashes and settles", () => {
    const frames = swapKeyframes({ x: 300, y: 0 })
    expect(frames[0]).toEqual({ offset: 0, transform: "translate(300px, 0px)" })
    const landing = frames.find((frame) => frame.offset === SWAP_LANDING)
    expect(landing?.transform).toBe("translate(0px, 0px)")
    expect(frames.at(-2)?.transform).toContain("scale(1.12, 0.86)")
    expect(frames.at(-1)).toEqual({ offset: 1, transform: "translate(0px, 0px) scale(1, 1)" })
    const offsets = frames.map((frame) => frame.offset as number)
    expect(offsets).toEqual([...offsets].sort((a, b) => a - b))
  })
})

describe("confettiDirections", () => {
  it("spreads the pieces around the burst, alternating two reaches", () => {
    const directions = confettiDirections(4, 100)
    expect(directions).toEqual([
      { x: 100, y: 0 },
      { x: 0, y: 65 },
      { x: -100, y: 0 },
      { x: 0, y: -65 },
    ])
  })
})
