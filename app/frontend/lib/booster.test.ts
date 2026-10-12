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
  revealingOpening,
  revealSummary,
  scaled,
  secondsUntil,
  shakeKeyframes,
  utcTime,
  DEAL_STAGGER as ROW_STAGGER,
  PHONE_DEAL_STAGGER,
  SWIPE_START,
  faceSize,
  layoutFor,
  phoneAllHold,
  phoneJump,
  phoneSwell,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  storedAfterRebuild,
  swipeStores,
  topOfPile,
  zoomNeighbour,
} from "./booster"
import type { BoosterStatus } from "./booster_props"

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

describe("revealingOpening", () => {
  it("is revealing from the canister arming until every card is shown", () => {
    const revealing: BoosterStatus[] = ["arming", "ejecting", "inventory", "legendarySignal"]
    revealing.forEach((status) => expect(revealingOpening(status)).toBe(true))
  })

  it("is not revealing while sealed, waiting for a pack or complete", () => {
    expect(revealingOpening("sealed")).toBe(false)
    expect(revealingOpening("waiting")).toBe(false)
    expect(revealingOpening("complete")).toBe(false)
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

describe("layouts", () => {
  it("are the phone under 720px, the narrow row under 900px, the wide row above", () => {
    expect(layoutFor(true, true)).toBe("phone")
    expect(layoutFor(false, true)).toBe("narrow")
    expect(layoutFor(false, false)).toBe("wide")
  })

  it("deal xl on the phone, s in the narrow row, m in the wide one", () => {
    expect(faceSize("phone")).toBe("xl")
    expect(faceSize("narrow")).toBe("s")
    expect(faceSize("wide")).toBe("m")
  })
})

describe("the phone's pile", () => {
  it("poses each card 5px lower, 2 % smaller and tilted one way then the other, 2.8° at most", () => {
    expect(pilePose(0)).toEqual({ y: 0, scale: 1, rotate: 0 })
    expect(pilePose(1)).toEqual({ y: 5, scale: 0.98, rotate: 1.4 })
    expect(pilePose(2)).toEqual({ y: 10, scale: 0.96, rotate: -2.8 })
    expect(pilePose(3)).toEqual({ y: 15, scale: 0.94, rotate: 2.8 })
    expect(pilePose(4)).toEqual({ y: 20, scale: 0.92, rotate: -2.8 })
    expect(pileTransform(1)).toBe("translate(0px, 5px) rotate(1.4deg) scale(0.98, 0.98)")
  })

  it("lands the bottom card first and keeps the first card on top", () => {
    expect(pileOrder(5)).toEqual([4, 3, 2, 1, 0])
    expect(pileOrder(3)).toEqual([2, 1, 0])
    expect(pileOrder(0)).toEqual([])
  })

  it("has on top the first card not stored, none once all are", () => {
    expect(topOfPile([false, false, false], [false, false, false])).toBe(0)
    expect(topOfPile([true, false, false], [true, false, false])).toBe(1)
    expect(topOfPile([true, false, true], [true, false, true])).toBe(1)
    expect(topOfPile([true, true], [true, true])).toBeNull()
  })

  it("counts a card's depth from the cards still above it", () => {
    expect(pileDepth(0, [false, false, false])).toBe(0)
    expect(pileDepth(2, [false, false, false])).toBe(2)
    expect(pileDepth(2, [true, false, false])).toBe(1)
    expect(pileDepth(3, [true, false, true, false])).toBe(1)
  })

  it("deals each card to its pile pose, so the flight ends where the card rests", () => {
    const frames = dealKeyframes(0, -200, 26, pilePose(2))
    expect(frames.at(-1)).toMatchObject({ opacity: 1, transform: pileTransform(2) })
    expect(frames[2].transform).toBe("translate(0px, 20px) rotate(-2.8deg) scale(1.094, 0.806)")
  })

  it("lands 1.5 times the row's stagger apart", () => {
    expect(PHONE_DEAL_STAGGER).toBe(Math.round(ROW_STAGGER * 1.5))
  })
})

describe("swipeStores", () => {
  it("stores after a long move sideways, up, or down toward the tray", () => {
    expect(swipeStores(65, 0)).toBe(true)
    expect(swipeStores(-65, 0)).toBe(true)
    expect(swipeStores(0, -65)).toBe(true)
    expect(swipeStores(0, 91)).toBe(true)
  })

  it("springs back after a short drag", () => {
    expect(swipeStores(64, 0)).toBe(false)
    expect(swipeStores(30, -64)).toBe(false)
    expect(swipeStores(-20, 90)).toBe(false)
    expect(SWIPE_START).toBe(10)
  })
})

describe("storedAfterRebuild", () => {
  it("lays every revealed card in the tray on the way into the phone", () => {
    expect(storedAfterRebuild([true, false, true, false], [false, false, false, false], "phone")).toEqual([true, false, true, false])
    expect(storedAfterRebuild([true, true, false], [true, false, false], "phone")).toEqual([true, true, false])
  })

  it("stores nothing in a row", () => {
    expect(storedAfterRebuild([true, true, false], [true, true, false], "wide")).toEqual([false, false, false])
    expect(storedAfterRebuild([true, false], [true, false], "narrow")).toEqual([false, false])
  })
})

describe("zoomNeighbour", () => {
  it("steps to the previous or next filled slot, in booster order", () => {
    const stored = [true, true, true, true, true]
    expect(zoomNeighbour(stored, 2, -1)).toBe(1)
    expect(zoomNeighbour(stored, 2, 1)).toBe(3)
  })

  it("skips the empty slots between", () => {
    expect(zoomNeighbour([true, false, false, true, false], 0, 1)).toBe(3)
    expect(zoomNeighbour([true, false, false, true, false], 3, -1)).toBe(0)
  })

  it("has none before the first filled slot nor after the last", () => {
    expect(zoomNeighbour([true, true, true], 0, -1)).toBeNull()
    expect(zoomNeighbour([true, true, true], 2, 1)).toBeNull()
    expect(zoomNeighbour([false, true, true, false], 1, -1)).toBeNull()
    expect(zoomNeighbour([false, true, true, false], 2, 1)).toBeNull()
  })
})

describe("the phone's motion", () => {
  it("keeps the Légendaire's jump to 60 % of the room above the card, 50px at most", () => {
    expect(phoneJump(200)).toBe(50)
    expect(phoneJump(40)).toBe(24)
    expect(phoneJump(0)).toBe(0)
    expect(phoneJump(-10)).toBe(0)
  })

  it("keeps a quarter of the reveal's swell, so the large card stays clear of the plate", () => {
    expect(phoneSwell(1)).toBe(1)
    expect(phoneSwell(1.15)).toBe(1.0375)
    expect(phoneSwell(0.9)).toBe(0.975)
  })

  it("holds an Épique or better longer before Tout révéler stores it", () => {
    expect(phoneAllHold("epic")).toBe(scaled(320))
    expect(phoneAllHold("legendary")).toBe(scaled(320))
    expect(phoneAllHold("rare")).toBe(scaled(150))
    expect(phoneAllHold("common")).toBe(scaled(150))
  })
})
