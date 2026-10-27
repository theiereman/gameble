import { describe, expect, it } from "vitest"
import { bankFrom, cardFrom, openedFrom, setTierFrom, thresholdsFrom } from "./booster_markup"

const BANK = { available: 2, reserveFull: false, nextAvailableAt: "2026-10-26T12:00:00.000Z", serverTime: "2026-10-26T11:00:00.000Z", nextPackSize: 5 }

describe("bankFrom", () => {
  it("reads the bank from the root's values, an empty time and a zero size as none", () => {
    expect(bankFrom(BANK)).toEqual(BANK)
    expect(bankFrom({ ...BANK, available: 0, nextAvailableAt: "", nextPackSize: 0 })).toEqual({ ...BANK, available: 0, nextAvailableAt: null, nextPackSize: null })
  })
})

describe("cardFrom", () => {
  it("reads a card's data, without a year when it has none", () => {
    const data = { slug: "portal", season: "1", tier: "epic", coverUrl: "/portal.jpg", title: "Portal", year: "2007", label: "Portal — Valve, 2007" }
    expect(cardFrom(data)).toEqual({ ...data, season: 1, year: 2007, faces: { s: "", m: "", xl: "" } })
    expect(cardFrom({ slug: "x", tier: "bogus", title: "X" })).toMatchObject({ season: 0, tier: "common", year: null, label: "X", coverUrl: "" })
  })
})

describe("thresholdsFrom, setTierFrom", () => {
  it("reads a set tier and its thresholds, skipping unknown tiers", () => {
    expect(thresholdsFrom("bronze:4 silver:16 bogus:3 gold:")).toEqual([
      { tier: "bronze", required: 4 },
      { tier: "silver", required: 16 },
    ])
    expect(thresholdsFrom(undefined)).toEqual([])
    const data = { kind: "studio", key: "valve", name: "Valve", tier: "complete", required: "3", held: "3", total: "3", thresholds: "novice:1", url: "/sets/valve" }
    expect(setTierFrom(data)).toEqual({ ...data, required: 3, held: 3, total: 3, thresholds: [{ tier: "novice", required: 1 }] })
    expect(setTierFrom({ ...data, tier: "bogus" })).toBeNull()
  })
})

describe("openedFrom", () => {
  const pack = { token: "abc", kind: "regular", cardBack: "standard", url: "/packs/abc" }
  const card = { slug: "portal", season: "1", tier: "epic", title: "Portal", label: "Portal" }

  it("rebuilds the opened pack as the opening exchange answers it", () => {
    const opened = openedFrom({ pack, cards: [card, card], setTiers: [{ kind: "studio", key: "valve", name: "Valve", tier: "complete", required: "1", held: "1", total: "1", url: "/v" }], bank: bankFrom(BANK) })
    expect(opened?.pack).toEqual(pack)
    expect(opened?.cards.map((each) => each.slug)).toEqual(["portal", "portal"])
    expect(opened?.setTiers).toHaveLength(1)
    expect(opened?.bank).toEqual({ available: 2, reserveFull: false, nextAvailableAt: BANK.nextAvailableAt, scheduledAt: [], nextPackSize: 5 })
    expect(opened?.serverTime).toBe(BANK.serverTime)
  })

  it("is none without a pack or a card", () => {
    expect(openedFrom({ pack: null, cards: [card], setTiers: [], bank: bankFrom(BANK) })).toBeNull()
    expect(openedFrom({ pack, cards: [], setTiers: [], bank: bankFrom(BANK) })).toBeNull()
  })
})
