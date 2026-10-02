import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  BURST_PIXELS,
  BURST_STEPS,
  STAGGER_MS,
  burstPixels,
  flip,
  flipLength,
  planFlipAll,
  revealLength,
  runFlipAll,
  wipe,
  type CardState,
  type FlipAllStep,
} from "./reveal"
import type { Rarity } from "../components/Card"

describe("card states", () => {
  it("wipes a dusty card once, and leaves a wiped or flipped one", () => {
    expect(wipe("dusty")).toBe("wiped")
    expect(wipe("wiped")).toBe("wiped")
    expect(wipe("flipped")).toBe("flipped")
  })

  it("flips a card from any state", () => {
    expect(flip("dusty")).toBe("flipped")
    expect(flip("wiped")).toBe("flipped")
  })
})

describe("lengths", () => {
  it("grow with the rarity, a gold card the longest", () => {
    const tiers: Rarity[] = ["steel", "emerald", "sapphire", "amethyst", "gold"]
    const lengths = tiers.map(revealLength)
    expect([...lengths].sort((a, b) => a - b)).toEqual(lengths)
    expect(new Set(lengths).size).toBe(5)
  })

  it("are the steel length in a quick flip, except a gold card's", () => {
    expect(flipLength("amethyst", "quick")).toBe(revealLength("steel"))
    expect(flipLength("gold", "quick")).toBe(revealLength("gold"))
    expect(flipLength("sapphire", "full")).toBe(revealLength("sapphire"))
  })
})

describe("planFlipAll", () => {
  const dusty = (count: number): CardState[] => Array(count).fill("dusty")

  it("staggers quick cards when there is no gold", () => {
    const { steps, end } = planFlipAll(["steel", "emerald", "sapphire", "amethyst", "steel"], dusty(5))
    expect(steps.map((step) => step.at)).toEqual([0, 1, 2, 3, 4].map((n) => n * STAGGER_MS))
    expect(steps.every((step) => step.mode === "quick" && step.length === revealLength("steel"))).toBe(true)
    expect(end).toBe(4 * STAGGER_MS + revealLength("steel"))
  })

  it("holds a gold card its full length before the next", () => {
    const { steps } = planFlipAll(["steel", "gold", "emerald", "steel", "steel"], ["dusty", "wiped", "dusty", "dusty", "dusty"])
    const gold = steps[1]
    expect(gold).toMatchObject({ index: 1, mode: "full", length: revealLength("gold") })
    expect(steps[2].at - gold.at).toBeGreaterThanOrEqual(revealLength("gold"))
  })

  it("holds each of two gold cards, and five identical gold cards one by one", () => {
    const two = planFlipAll(["gold", "steel", "gold", "steel", "steel"], dusty(5)).steps
    expect(two[1].at - two[0].at).toBeGreaterThanOrEqual(revealLength("gold"))
    expect(two[3].at - two[2].at).toBeGreaterThanOrEqual(revealLength("gold"))

    const five = planFlipAll(Array(5).fill("gold"), dusty(5))
    expect(five.steps.map((step) => step.index)).toEqual([0, 1, 2, 3, 4])
    five.steps.slice(1).forEach((step, n) => expect(step.at - five.steps[n].at).toBe(revealLength("gold")))
    expect(five.end).toBe(5 * revealLength("gold"))
  })

  it("skips flipped cards, a flipped gold card included", () => {
    const { steps } = planFlipAll(["steel", "gold", "emerald"], ["flipped", "flipped", "wiped"])
    expect(steps).toEqual([{ index: 2, at: 0, mode: "quick", length: revealLength("steel") }])
  })

  it("plans nothing when every card is flipped", () => {
    expect(planFlipAll(["steel", "gold"], ["flipped", "flipped"])).toEqual({ steps: [], end: 0 })
  })
})

describe("runFlipAll", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  const timers = {
    setTimeout: (callback: () => void, ms: number) => setTimeout(callback, ms),
    clearTimeout: (handle: unknown) => clearTimeout(handle as ReturnType<typeof setTimeout>),
  }

  it("flips each card at its time, then ends", () => {
    const plan = planFlipAll(["steel", "gold", "emerald"], ["dusty", "dusty", "dusty"])
    const flipped: { index: number; at: number }[] = []
    const onEnd = vi.fn()
    const start = Date.now()
    runFlipAll(plan, { onStep: (step: FlipAllStep) => flipped.push({ index: step.index, at: Date.now() - start }), onEnd }, timers)

    vi.advanceTimersByTime(STAGGER_MS)
    expect(flipped.map((card) => card.index)).toEqual([0, 1])
    vi.advanceTimersByTime(revealLength("gold") - 1)
    expect(flipped.map((card) => card.index)).toEqual([0, 1])
    vi.advanceTimersByTime(1)
    expect(flipped.map((card) => card.index)).toEqual([0, 1, 2])
    expect(flipped[2].at - flipped[1].at).toBeGreaterThanOrEqual(revealLength("gold"))
    expect(onEnd).not.toHaveBeenCalled()

    vi.advanceTimersByTime(revealLength("steel"))
    expect(onEnd).toHaveBeenCalledOnce()
  })

  it("clears every timer when cancelled", () => {
    const onStep = vi.fn()
    const onEnd = vi.fn()
    const cancel = runFlipAll(planFlipAll(["gold", "steel"], ["dusty", "dusty"]), { onStep, onEnd }, timers)
    vi.advanceTimersByTime(0)
    expect(onStep).toHaveBeenCalledOnce()

    cancel()
    vi.runAllTimers()
    expect(onStep).toHaveBeenCalledOnce()
    expect(onEnd).not.toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
  })

  it("runs on the browser's timers by default", () => {
    const onEnd = vi.fn()
    runFlipAll(planFlipAll(["steel"], ["dusty"]), { onStep: () => {}, onEnd })
    vi.advanceTimersByTime(revealLength("steel"))
    expect(onEnd).toHaveBeenCalledOnce()
  })
})

describe("burstPixels", () => {
  it("gives more pixels to rarer cards, the same ones each time, on the 2 px grid at every step", () => {
    expect(burstPixels("steel", 160, 240)).toHaveLength(BURST_PIXELS.steel)
    expect(burstPixels("gold", 160, 240)).toHaveLength(BURST_PIXELS.gold)
    expect(burstPixels("gold", 240, 360)).toEqual(burstPixels("gold", 240, 360))
    for (const { x, y, dx, dy } of burstPixels("gold", 240, 360)) {
      for (const value of [x, y, dx / BURST_STEPS, dy / BURST_STEPS]) expect(Math.abs(value) % 2).toBe(0)
    }
  })
})
