import { describe, expect, it } from "vitest"
import {
  countsAfterReveal,
  faceSize,
  keyAfter,
  layoutFor,
  planRevealAll,
  revealingOpening,
  storedAfterRebuild,
  topOfPile,
  zoomNeighbour,
} from "./booster_rules"
import { BoosterStatus, NARROW_QUERY, PHONE_QUERY } from "./booster_types"

describe("layouts", () => {
  it("are the phone under 720px, the narrow row under 900px, the wide row above", () => {
    expect(layoutFor(true, true)).toBe("phone")
    expect(layoutFor(false, true)).toBe("narrow")
    expect(layoutFor(false, false)).toBe("wide")
    expect([PHONE_QUERY, NARROW_QUERY]).toEqual(["(max-width: 719px)", "(max-width: 899px)"])
  })

  it("deal xl on the phone, s in the narrow row, m in the wide one", () => {
    expect(faceSize("phone")).toBe("xl")
    expect(faceSize("narrow")).toBe("s")
    expect(faceSize("wide")).toBe("m")
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

describe("planRevealAll", () => {
  it("lists the face-down cards in order, a legendary awaited in full", () => {
    expect(
      planRevealAll(["common", "legendary", "rare", "legendary", "epic"], [false, false, true, false, false]),
    ).toEqual([
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

describe("topOfPile", () => {
  it("has on top the first card not stored, none once all are", () => {
    expect(topOfPile([false, false, false], [false, false, false])).toBe(0)
    expect(topOfPile([true, false, false], [true, false, false])).toBe(1)
    expect(topOfPile([true, false, true], [true, false, true])).toBe(1)
    expect(topOfPile([true, true], [true, true])).toBeNull()
  })
})

describe("storedAfterRebuild", () => {
  it("lays every revealed card in the tray on the way into the phone", () => {
    expect(storedAfterRebuild([true, false, true, false], [false, false, false, false], "phone")).toEqual([
      true,
      false,
      true,
      false,
    ])
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
