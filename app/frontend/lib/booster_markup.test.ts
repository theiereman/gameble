import { describe, expect, it } from "vitest"
import { bankFrom, cardFrom, openedFrom, setTierFrom, thresholdsFrom } from "./booster_markup"

const BANK = {
  available: 2,
  special: 1,
  openable: 3,
  reserveFull: false,
  nextSpecialKind: "bonus",
  nextAvailableAt: "2026-10-26T12:00:00.000Z",
  serverTime: "2026-10-26T11:00:00.000Z",
  nextPackSize: 5,
}

describe("bankFrom", () => {
  it("reads the bank from the root's values, an empty time and a zero size as none", () => {
    expect(bankFrom(BANK)).toEqual(BANK)
    expect(bankFrom({ ...BANK, available: 0, nextAvailableAt: "", nextPackSize: 0 })).toEqual({
      ...BANK,
      available: 0,
      nextAvailableAt: null,
      nextPackSize: null,
    })
  })
})

describe("cardFrom", () => {
  it("reads a card's data, without a year when it has none", () => {
    const data = {
      slug: "portal",
      season: "1",
      tier: "epic",
      coverUrl: "/portal.jpg",
      title: "Portal",
      year: "2007",
      label: "Portal — Valve, 2007",
    }
    expect(cardFrom(data)).toEqual({ ...data, season: 1, year: 2007, faces: { s: "", m: "", xl: "" } })
    expect(cardFrom({ slug: "x", tier: "bogus", title: "X" })).toMatchObject({
      season: 0,
      tier: "common",
      year: null,
      label: "X",
      coverUrl: "",
    })
  })
})

describe("thresholdsFrom, setTierFrom", () => {
  it("reads a set tier and its thresholds, skipping unknown tiers", () => {
    expect(thresholdsFrom("bronze:4 silver:16 bogus:3 gold:")).toEqual([
      { tier: "bronze", required: 4 },
      { tier: "silver", required: 16 },
    ])
    expect(thresholdsFrom(undefined)).toEqual([])
    const data = {
      kind: "studio",
      key: "valve",
      name: "Valve",
      tier: "complete",
      required: "3",
      held: "3",
      total: "3",
      thresholds: "novice:1",
      url: "/sets/valve",
    }
    expect(setTierFrom(data)).toEqual({
      ...data,
      required: 3,
      held: 3,
      total: 3,
      thresholds: [{ tier: "novice", required: 1 }],
    })
    expect(setTierFrom({ ...data, tier: "bogus" })).toBeNull()
  })
})

describe("openedFrom", () => {
  const pack = { token: "abc", kind: "regular", cardBack: "standard", url: "/packs/abc" }
  const card = { slug: "portal", season: "1", tier: "epic", title: "Portal", label: "Portal" }

  it("rebuilds the opened pack as the opening exchange answers it", () => {
    const opened = openedFrom({
      pack,
      cards: [card, card],
      setTiers: [
        {
          kind: "studio",
          key: "valve",
          name: "Valve",
          tier: "complete",
          required: "1",
          held: "1",
          total: "1",
          url: "/v",
        },
      ],
      bank: bankFrom(BANK),
    })
    expect(opened?.pack).toEqual({ ...pack, cardBack: { key: "standard", urls: null } })
    expect(opened?.cards.map((each) => each.slug)).toEqual(["portal", "portal"])
    expect(opened?.setTiers).toHaveLength(1)
    expect(opened?.bank).toEqual({
      available: 2,
      special: 1,
      openable: 3,
      reserveFull: false,
      nextSpecialKind: "bonus",
      nextAvailableAt: BANK.nextAvailableAt,
      scheduledAt: [],
      nextPackSize: 5,
    })
    expect(opened?.serverTime).toBe(BANK.serverTime)
  })

  it("reads the sizes of the pack's back, and none when one is missing", () => {
    const sizes = { cardBackS: "/s.png", cardBackM: "/m.png", cardBackXl: "/xl.png" }
    const open = (dataset: Record<string, string>) =>
      openedFrom({ pack: { ...pack, ...dataset }, cards: [card], setTiers: [], bank: bankFrom(BANK) })

    expect(open({ cardBack: "set-theme-rpg", ...sizes })?.pack.cardBack).toEqual({
      key: "set-theme-rpg",
      urls: { s: "/s.png", m: "/m.png", xl: "/xl.png" },
    })
    expect(open({ cardBack: "set-theme-rpg", cardBackS: "/s.png" })?.pack.cardBack.urls).toBeNull()
  })

  it("reads the season the pack's back wore, and none when the attribute is missing or not a season", () => {
    const open = (dataset: Record<string, string>) =>
      openedFrom({ pack: { ...pack, ...dataset }, cards: [card], setTiers: [], bank: bankFrom(BANK) })

    expect(open({ cardBack: "set-theme-rpg", cardBackSeason: "2" })?.pack.cardBack.season).toBe(2)
    expect(open({ cardBack: "set-theme-rpg" })?.pack.cardBack.season).toBeUndefined()
    expect(open({ cardBack: "set-theme-rpg", cardBackSeason: "x" })?.pack.cardBack.season).toBeUndefined()
  })

  it("is none without a pack or a card", () => {
    expect(openedFrom({ pack: null, cards: [card], setTiers: [], bank: bankFrom(BANK) })).toBeNull()
    expect(openedFrom({ pack, cards: [], setTiers: [], bank: bankFrom(BANK) })).toBeNull()
  })
})
