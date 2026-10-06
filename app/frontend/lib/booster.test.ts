import { describe, expect, it } from "vitest"
import {
  ARM_MS,
  BODY_MS,
  BURST_PIXELS,
  CAPS_MS,
  DEAL_MS,
  DEAL_STAGGER,
  DROP,
  FLASH_MS,
  FLIP_MS,
  HEAD_DELAY,
  IMPACT,
  IMPACT_AT,
  LEGENDARY_JUMP,
  MARK_IN_SPIN,
  SETTLE_MS,
  SHAKE_MS,
  SPIN,
  TIME_SCALE,
  TREMBLE_MS,
  burstPixels,
  countsAfterReveal,
  cardBackClass,
  dealKeyframes,
  dealOrder,
  formatClock,
  keyAfter,
  planRevealAll,
  revealSummary,
  scaled,
  secondsUntil,
  shakeKeyframes,
  utcTime,
} from "./booster"

describe("timings", () => {
  it("are the prototype's, multiplied by 1.18 and rounded", () => {
    expect(TIME_SCALE).toBe(1.18)
    const bases: [number, number][] = [
      [ARM_MS, 320],
      [CAPS_MS, 620],
      [BODY_MS, 150],
      [FLASH_MS, 170],
      [SHAKE_MS, 300],
      [HEAD_DELAY, 60],
      [DEAL_MS, 460],
      [DEAL_STAGGER, 45],
      [LEGENDARY_JUMP, 520],
      [SPIN, 560],
      [MARK_IN_SPIN, 90],
      [IMPACT_AT, 420],
      [IMPACT, 760],
      [DROP, 380],
    ]
    for (const [value, base] of bases) expect(value).toBe(Math.round(base * 1.18))
    expect(scaled(320)).toBe(378)
  })

  it("match the plan's values", () => {
    expect([ARM_MS, CAPS_MS, BODY_MS, FLASH_MS, SHAKE_MS, HEAD_DELAY, DEAL_MS, DEAL_STAGGER]).toEqual([378, 732, 177, 201, 354, 71, 543, 53])
    expect([LEGENDARY_JUMP, SPIN, MARK_IN_SPIN, IMPACT, DROP]).toEqual([614, 661, 106, 897, 448])
  })

  it("grow with the tier", () => {
    expect(TREMBLE_MS).toEqual([0, 90, 170, 280].map((base) => Math.round(base * 1.18)))
    expect(FLIP_MS).toEqual([300, 340, 380, 420].map((base) => Math.round(base * 1.18)))
    expect(SETTLE_MS).toEqual([380, 440, 500, 560].map((base) => Math.round(base * 1.18)))
  })
})

describe("dealOrder", () => {
  it("deals centre out", () => {
    expect(dealOrder(5)).toEqual([2, 1, 3, 0, 4])
    expect(dealOrder(3)).toEqual([1, 0, 2])
    expect(dealOrder(4)).toEqual([2, 1, 3, 0])
    expect(dealOrder(1)).toEqual([0])
    expect(dealOrder(0)).toEqual([])
  })
})

describe("planRevealAll", () => {
  it("lists the face-down cards in order, a legendary awaited in full", () => {
    expect(planRevealAll(["common", "legendary", "rare", "legendary", "epic"], [false, false, true, false, false])).toEqual([
      { index: 0, wait: "gap" },
      { index: 1, wait: "full" },
      { index: 3, wait: "full" },
      { index: 4, wait: "gap" },
    ])
    expect(planRevealAll(["common"], [true])).toEqual([])
  })
})

describe("keyAfter", () => {
  const key = "3c1f9a2e-7d4b-4c8a-b5e6-0f2d9e8a1b7c"

  it("keeps the key after an unknown outcome or a throttle", () => {
    expect(keyAfter({ kind: "failed" }, key)).toBe(key)
    expect(keyAfter({ kind: "refused", code: "throttled" }, key)).toBe(key)
  })

  it("drops it after a success or any other refusal", () => {
    expect(keyAfter({ kind: "opened" }, key)).toBeNull()
    expect(keyAfter({ kind: "refused", code: "no_pack_available" }, key)).toBeNull()
    expect(keyAfter({ kind: "refused", code: "sign_in_required" }, key)).toBeNull()
  })
})

describe("countsAfterReveal", () => {
  it("adds one copy to the tier, leaving the counts given as they were", () => {
    const counts = { common: 3, uncommon: 0, rare: 1, epic: 0, legendary: 0 }
    expect(countsAfterReveal(counts, "rare")).toEqual({ common: 3, uncommon: 0, rare: 2, epic: 0, legendary: 0 })
    expect(counts.rare).toBe(1)
  })
})

describe("revealSummary", () => {
  const strings = {
    summary: { one: "%{n} carte révélée : %{tiers}.", other: "%{n} cartes révélées : %{tiers}." },
    summaryTier: "%{rarity} × %{n}",
    rarityNames: { common: "Commune", uncommon: "Peu commune", rare: "Rare", epic: "Épique", legendary: "Légendaire" },
    delimiter: " ",
  }

  it("names each tier revealed, rarest first", () => {
    expect(revealSummary(["common", "legendary", "common"], strings)).toBe("3 cartes révélées : Légendaire × 1, Commune × 2.")
    expect(revealSummary(["rare"], strings)).toBe("1 carte révélée : Rare × 1.")
  })
})

describe("formatClock", () => {
  it("shows hours from an hour, else minutes and seconds", () => {
    expect(formatClock(59)).toBe("00:59")
    expect(formatClock(600)).toBe("10:00")
    expect(formatClock(3599)).toBe("59:59")
    expect(formatClock(3600)).toBe("1:00:00")
    expect(formatClock(6130)).toBe("1:42:10")
    expect(formatClock(-4)).toBe("00:00")
  })
})

describe("secondsUntil", () => {
  it("counts whole seconds from the server's time, rounded up", () => {
    expect(secondsUntil("2026-10-06T14:32:00.000Z", "2026-10-06T14:22:00.000Z")).toBe(600)
    expect(secondsUntil("2026-10-06T14:32:00.000Z", "2026-10-06T14:31:59.500Z")).toBe(1)
    expect(secondsUntil("2026-10-06T14:22:00.000Z", "2026-10-06T14:23:00.000Z")).toBe(0)
    expect(secondsUntil(null, "2026-10-06T14:22:00.000Z")).toBeNull()
  })

  it("reads the UTC time of a booster", () => {
    expect(utcTime("2026-10-06T09:40:00.000Z")).toBe("09:40")
  })
})

describe("burstPixels", () => {
  it("flies more pixels as the tier rises, each on the 2 px grid", () => {
    for (const tier of ["common", "uncommon", "rare", "epic", "legendary"] as const) {
      const pixels = burstPixels(tier, 160, 240)
      expect(pixels).toHaveLength(BURST_PIXELS[tier])
      for (const { x, y, dx, dy } of pixels) for (const value of [x, y, dx, dy]) expect(Math.abs(value) % 2).toBe(0)
    }
    expect(burstPixels("rare", 160, 240)).toEqual(burstPixels("rare", 160, 240))
  })
})

describe("keyframes", () => {
  it("deal from the canister to rest, fully shown from the arc on", () => {
    const frames = dealKeyframes(-200, -120, 26)
    expect(frames[0]).toMatchObject({ opacity: 0, transform: "translate(-200px, -120px) rotate(26deg) scale(0.2, 0.2)" })
    expect(frames.at(-1)).toMatchObject({ opacity: 1, transform: "translate(0px, 0px) rotate(0deg) scale(1, 1)" })
    expect(frames.map((frame) => frame.offset).filter((offset) => offset !== undefined)).toEqual([0.42, 0.7, 0.86])
  })

  it("shake in eight decaying steps back to rest", () => {
    const frames = shakeKeyframes(5)
    expect(frames).toHaveLength(9)
    expect(frames[0].transform).toBe("translate(5.0px, -3.0px)")
    expect(frames.at(-1)?.transform).toBe("translate(0px, 0px)")
  })
})

describe("cardBackClass", () => {
  it("names the back of a known key, and the standard back for any other", () => {
    expect(cardBackClass("standard")).toBe("booster-card__back--standard")
    expect(cardBackClass("aurora")).toBe("booster-card__back--standard")
    expect(cardBackClass("")).toBe("booster-card__back--standard")
  })
})
