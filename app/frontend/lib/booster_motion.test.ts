import { describe, expect, it } from "vitest"
import {
  EPIC_BANNER_MS,
  LEGENDARY_BANNER_MS,
  RM_LEGENDARY_STILL,
  bannerDuration,
  BURST_PIXELS,
  burstPixels,
  cardBackClass,
  cardBackProperties,
  cardBackSeasonMark,
  revealSummary,
  scaled,
  SWIPE_START,
  phoneAllHold,
  phoneJump,
  phoneSwell,
  pileDepth,
  pileOrder,
  pilePose,
  pileTransform,
  swipeStores,
} from "./booster_motion"

describe("bannerDuration", () => {
  it("holds a still banner under reduced motion, a Légendaire's longer than an Épique's otherwise", () => {
    expect(bannerDuration({ reduced: true, large: true })).toBe(RM_LEGENDARY_STILL)
    expect(bannerDuration({ reduced: false, large: true })).toBe(LEGENDARY_BANNER_MS)
    expect(bannerDuration({ reduced: false, large: false })).toBe(EPIC_BANNER_MS)
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
    expect(revealSummary(["common", "legendary", "common"], strings)).toBe(
      "3 cartes révélées : Légendaire × 1, Commune × 2.",
    )
    expect(revealSummary(["rare"], strings)).toBe("1 carte révélée : Rare × 1.")
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

describe("the card back", () => {
  const urls = { s: "/s.png", m: "/m.png", xl: "/xl.png" }

  it("wears the server's drawing when the pack carries its sizes, and the standard back otherwise", () => {
    expect(cardBackClass({ key: "set-theme-rpg", urls })).toBe("booster-card__back--custom")
    expect(cardBackClass({ key: "standard", urls: null })).toBe("booster-card__back--standard")
    expect(cardBackClass({ key: "unknown", urls: null })).toBe("booster-card__back--standard")
  })

  it("hands the three sizes to the stylesheet as properties, none for the standard back", () => {
    expect(cardBackProperties({ key: "set-theme-rpg", urls })).toEqual([
      ["--card-back-s", 'url("/s.png")'],
      ["--card-back-m", 'url("/m.png")'],
      ["--card-back-xl", 'url("/xl.png")'],
    ])
    expect(cardBackProperties({ key: "standard", urls: null })).toEqual([])
  })

  it("stamps the season the pack's back wore, and nothing when it wore none", () => {
    expect(cardBackSeasonMark({ key: "set-theme-rpg", urls, season: 2 })).toBe("S2")
    expect(cardBackSeasonMark({ key: "set-theme-rpg", urls })).toBeNull()
    expect(cardBackSeasonMark({ key: "set-theme-rpg", urls, season: null })).toBeNull()
  })
})

describe("the phone's pile", () => {
  it("lands the bottom card first and keeps the first card on top", () => {
    expect(pileOrder(5)).toEqual([4, 3, 2, 1, 0])
    expect(pileOrder(3)).toEqual([2, 1, 0])
    expect(pileOrder(0)).toEqual([])
  })

  it("counts a card's depth from the cards still above it", () => {
    expect(pileDepth(0, [false, false, false])).toBe(0)
    expect(pileDepth(2, [false, false, false])).toBe(2)
    expect(pileDepth(2, [true, false, false])).toBe(1)
    expect(pileDepth(3, [true, false, true, false])).toBe(1)
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
