import { describe, expect, it } from "vitest"
import {
  LANDS_AT,
  MIN_SHARE,
  celebrationAnnouncement,
  celebrationResults,
  countParts,
  fillReaches,
  folded,
  foldedLinkName,
  foldedMarks,
  foldedSubline,
  foldedTitle,
  gaugeFractions,
  gaugeTicks,
  juice,
  nextResult,
  notchCount,
  resultLinkName,
  resultTitle,
  restoredCelebration,
  sparkOffsets,
  type CelebrationStrings,
} from "./celebration"
import type { OpeningSetTier } from "./opening"

// As config/locales/fr.yml words them.
const fr: CelebrationStrings = {
  tierTitle: "PALIER %{tier}",
  completeTitle: "SET COMPLET",
  count: "%{owned}/%{total}",
  tiers: { bronze: "BRONZE", silver: "ARGENT", gold: "OR", complete: "COMPLET" },
  folded: { zero: "%{count} PALIER ATTEINT", one: "%{count} PALIER ATTEINT", other: "%{count} PALIERS ATTEINTS" },
  foldedLead: "dont",
  setHint: "VOIR LE SET",
  foldedHint: "EN COURS",
  openSet: "Voir le set.",
  openInProgress: "Voir les sets en cours.",
  position: "%{index} / %{count}",
  next: "Résultat suivant",
  announceTier: "Palier %{tier} atteint : %{set}, %{owned} cartes sur %{total}.",
  announceComplete: "Set complet : %{set}, %{owned} cartes sur %{total}.",
  announceFolded: { zero: "%{count} palier atteint : %{list}.", one: "%{count} palier atteint : %{list}.", other: "%{count} paliers atteints : %{list}." },
  announceItem: "%{set}, %{tier}",
  announceSeparator: " ; ",
  spokenTiers: { bronze: "bronze", silver: "argent", gold: "or", complete: "complet" },
}

const en: CelebrationStrings = {
  ...fr,
  tierTitle: "%{tier} TIER",
  completeTitle: "SET COMPLETE",
  tiers: { bronze: "BRONZE", silver: "SILVER", gold: "GOLD", complete: "COMPLETE" },
  folded: { one: "%{count} TIER REACHED", other: "%{count} TIERS REACHED" },
  foldedLead: "incl.",
  setHint: "VIEW SET",
  foldedHint: "IN PROGRESS",
  openSet: "View set.",
  openInProgress: "View sets in progress.",
  next: "Next result",
  announceTier: "%{tier} tier reached: %{set}, %{owned} cards out of %{total}.",
  announceComplete: "Set complete: %{set}, %{owned} cards out of %{total}.",
  announceFolded: { one: "%{count} tier reached: %{list}.", other: "%{count} tiers reached: %{list}." },
  announceSeparator: "; ",
  spokenTiers: { bronze: "bronze", silver: "silver", gold: "gold", complete: "complete" },
}

const NBSP = " "

const slug = (name: string): string => name.toLowerCase().replace(/\s+/g, "-")

const reached = (name: string, tier: OpeningSetTier["tier"], required: number, total: number, kind = "theme"): OpeningSetTier => ({
  kind,
  key: slug(name),
  name,
  tier,
  required,
  total,
  url: `/fr/library/${kind}/${slug(name)}`,
})

describe("celebrationResults", () => {
  it("keeps one result per set, its highest tier: gold and complete together are SET COMPLET", () => {
    const results = celebrationResults([
      reached("Roguelike", "bronze", 7, 62),
      reached("Roguelike", "silver", 16, 62),
      reached("Hades", "gold", 2, 3, "franchise"),
      reached("Hades", "complete", 3, 3, "franchise"),
    ])

    expect(results.map(({ name, tier, owned, total }) => [name, tier, owned, total])).toEqual([
      ["Hades", "complete", 3, 3],
      ["Roguelike", "silver", 16, 62],
    ])
  })

  it("tells sets of different kinds apart under the same key", () => {
    const results = celebrationResults([reached("Valve", "complete", 3, 3, "studio"), reached("Valve", "complete", 2, 2, "franchise")])
    expect(results).toHaveLength(2)
  })

  it("puts the highest tiers first, then the sets by name", () => {
    const results = celebrationResults([
      reached("Roguelike", "bronze", 7, 62),
      reached("Pirates", "gold", 9, 18),
      reached("Cosy", "bronze", 6, 54),
      reached("Dark Souls", "complete", 3, 3, "franchise"),
      reached("Metroidvania", "gold", 39, 77),
    ])

    expect(results.map((result) => result.name)).toEqual(["Dark Souls", "Metroidvania", "Pirates", "Cosy", "Roguelike"])
  })

  it("is empty when the opening reached nothing", () => {
    expect(celebrationResults([])).toEqual([])
  })

  it("leads each result to its set's album", () => {
    const [result] = celebrationResults([reached("Roguelike", "silver", 16, 62)])
    expect(result.url).toBe("/fr/library/theme/roguelike")
  })

  it("starts the count one card under the lowest tier the opening reached, never under zero", () => {
    const [silver] = celebrationResults([reached("Roguelike", "silver", 16, 62)])
    expect([silver.before, silver.owned, silver.crossed]).toEqual([15, 16, ["silver"]])

    const [double] = celebrationResults([reached("Cosy", "silver", 1, 3), reached("Cosy", "bronze", 1, 3)])
    expect([double.tier, double.before, double.crossed]).toEqual(["silver", 0, ["bronze", "silver"]])

    const [complete] = celebrationResults([reached("Metroidvania", "gold", 31, 62), reached("Metroidvania", "complete", 62, 62)])
    expect([complete.tier, complete.before, complete.owned, complete.crossed]).toEqual(["complete", 30, 62, ["gold", "complete"]])
  })
})

describe("restoredCelebration", () => {
  const tiers = [reached("Roguelike", "silver", 16, 62)]

  it("shows the results again on the way back from an album the celebration opened", () => {
    expect(restoredCelebration(tiers, true)?.map((result) => [result.name, result.tier])).toEqual([["Roguelike", "silver"]])
  })

  it("shows nothing on the way back from anywhere else, or when the pack reached nothing", () => {
    expect(restoredCelebration(tiers, false)).toBeNull()
    expect(restoredCelebration([], true)).toBeNull()
  })
})

describe("the results as shown", () => {
  it("titles a tier by its name and a completed set as SET COMPLET", () => {
    const [complete, silver] = celebrationResults([reached("Roguelike", "silver", 16, 62), reached("Dark Souls", "complete", 3, 3, "franchise")])

    expect(resultTitle(silver, fr)).toBe("PALIER ARGENT")
    expect(resultTitle(complete, fr)).toBe("SET COMPLET")
    expect([notchCount("bronze"), notchCount("silver"), notchCount("gold"), notchCount("complete")]).toEqual([1, 2, 3, 0])
  })

  it("rolls the count from the figure before the capsule to the new one", () => {
    const [silver] = celebrationResults([reached("Roguelike", "silver", 1016, 1062)])
    expect(countParts(silver, fr, NBSP)).toEqual({ before: `1${NBSP}015`, owned: `1${NBSP}016`, rest: `/1${NBSP}062` })
  })

  it("folds more than three results into one line", () => {
    const three = celebrationResults(["A", "B", "C"].map((name) => reached(name, "bronze", 2, 20)))
    const four = celebrationResults(["A", "B", "C", "D"].map((name) => reached(name, "bronze", 2, 20)))

    expect(folded(three)).toBe(false)
    expect(folded(four)).toBe(true)
    expect(foldedTitle(four, fr)).toBe("4 PALIERS ATTEINTS")
  })

  it("steps the phone's results in order, back to the first after the last", () => {
    expect([nextResult(0, 3), nextResult(1, 3), nextResult(2, 3)]).toEqual([1, 2, 0])
    expect(nextResult(0, 1)).toBe(0)
  })
})

describe("the gauge", () => {
  it("fills to the count before the capsule, then to the new count", () => {
    const [silver] = celebrationResults([reached("Roguelike", "silver", 16, 62)])
    const { from, to } = gaugeFractions(silver)
    expect(from).toBeCloseTo(15 / 62)
    expect(to).toBeCloseTo(16 / 62)
  })

  it("never draws this capsule's share narrower than its floor", () => {
    const [bronze] = celebrationResults([reached("FPS", "bronze", 76, 752)])
    const { from, to } = gaugeFractions(bronze)
    expect(from).toBeCloseTo(75 / 752)
    expect(to - from).toBeCloseTo(MIN_SHARE)

    const [complete] = celebrationResults([reached("Dark Souls", "complete", 1000, 1000, "franchise")])
    expect(gaugeFractions(complete).to).toBe(1)
  })

  it("lights the tick crossed, keeps the lower tier solid and the higher pending", () => {
    const [silver] = celebrationResults([reached("Roguelike", "silver", 16, 62)])
    const ticks = gaugeTicks(silver)

    expect(ticks.map(({ tier, state }) => [tier, state])).toEqual([
      ["bronze", "solid"],
      ["silver", "crossed"],
      ["gold", "pending"],
    ])
    expect(ticks[1].lightAt).toBe(LANDS_AT)
  })

  it("lights both ticks of a double crossing, the lower as the fill passes it, the result's own last", () => {
    const [double] = celebrationResults([reached("Cosy", "bronze", 1, 3), reached("Cosy", "silver", 1, 3)])
    const [bronze, silver, gold] = gaugeTicks(double)

    expect([bronze.state, silver.state, gold.state]).toEqual(["crossed", "crossed", "pending"])
    expect(bronze.lightAt).toBe(fillReaches(0.1, gaugeFractions(double)))
    expect(silver.lightAt).toBe(LANDS_AT)
    expect(bronze.lightAt!).toBeLessThan(silver.lightAt!)
  })

  it("lights a tick as the fill passes it: the count before over the first 45 % of the fill, the capsule's share over the rest", () => {
    const fill = { from: 0.2, to: 0.3 }
    expect(fillReaches(0.1, fill)).toBe(Math.round(80 + 380 * 0.45 * 0.5))
    expect(fillReaches(0.2, fill)).toBe(Math.round(80 + 380 * 0.45))
    expect(fillReaches(0.25, fill)).toBe(Math.round(80 + 380 * (0.45 + 0.55 * 0.5)))
    expect(fillReaches(0.3, fill)).toBe(80 + 380)
  })

  it("has no ticks for SET COMPLET, whose bar turns lime", () => {
    const [complete] = celebrationResults([reached("Dark Souls", "complete", 3, 3, "franchise")])
    expect(gaugeTicks(complete)).toEqual([])
  })
})

describe("the juice", () => {
  it("grows with the tier", () => {
    expect(juice("bronze")).toEqual({ tickSparks: 0, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false })
    expect(juice("silver")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 1, glints: false })
    expect(juice("gold")).toEqual({ tickSparks: 12, endSparks: 0, ribbonSparks: 8, glosses: 2, glints: true })
    expect(juice("complete")).toEqual({ tickSparks: 0, endSparks: 18, ribbonSparks: 14, glosses: 2, glints: true })
  })

  it("throws the same sparks every time, on the 2px grid", () => {
    const sparks = sparkOffsets(6, 22)
    expect(sparks).toEqual(sparkOffsets(6, 22))
    expect(sparks).toHaveLength(6)
    expect(sparks.map(({ k }) => k)).toEqual([0, 1, 2, 0, 1, 2])
    for (const { dx, dy } of sparks) {
      expect(Math.abs(dx) % 2).toBe(0)
      expect(Math.abs(dy) % 2).toBe(0)
    }
    expect(sparkOffsets(0, 22)).toEqual([])
  })
})

describe("the folded line", () => {
  const four = () =>
    celebrationResults([
      reached("Roguelike", "silver", 16, 62),
      reached("Metroidvania", "gold", 31, 62),
      reached("Les Pépites", "bronze", 3, 30),
      reached("Dark Souls", "complete", 3, 3, "franchise"),
    ])

  it("lights the marks of every tier reached, one after another", () => {
    expect(foldedMarks(four())).toEqual([
      { tier: "bronze", lightAt: 80 },
      { tier: "silver", lightAt: 170 },
      { tier: "gold", lightAt: 260 },
      { tier: "complete", lightAt: 350 },
    ])
  })

  it("leaves hollow the marks of tiers not reached", () => {
    const bronzes = celebrationResults(["A", "B", "C", "D"].map((name) => reached(name, "bronze", 2, 20)))
    expect(foldedMarks(bronzes).map(({ tier, lightAt }) => [tier, lightAt])).toEqual([
      ["bronze", 80],
      ["silver", null],
      ["gold", null],
      ["complete", null],
    ])
  })

  it("names only the highest result", () => {
    expect(foldedSubline(four(), fr)).toEqual({ lead: "dont", set: "Dark Souls", tier: "COMPLET" })
    expect(foldedSubline(four(), en)).toEqual({ lead: "incl.", set: "Dark Souls", tier: "COMPLETE" })
  })
})

describe("the link names", () => {
  it("repeat the result's message and end with where it leads", () => {
    const [complete, silver] = celebrationResults([reached("Roguelike", "silver", 16, 62), reached("Dark Souls", "complete", 3, 3, "franchise")])

    expect(resultLinkName(silver, fr, NBSP)).toBe("Palier argent atteint : Roguelike, 16 cartes sur 62. Voir le set.")
    expect(resultLinkName(complete, fr, NBSP)).toBe("Set complet : Dark Souls, 3 cartes sur 3. Voir le set.")
    expect(resultLinkName(silver, en, ",")).toBe("Silver tier reached: Roguelike, 16 cards out of 62. View set.")
  })

  it("name the folded line's sets and end with the sets in progress", () => {
    const results = celebrationResults([
      reached("Roguelike", "silver", 16, 62),
      reached("Metroidvania", "gold", 31, 62),
      reached("Les Pépites", "bronze", 3, 30),
      reached("Dark Souls", "complete", 3, 3, "franchise"),
    ])

    expect(foldedLinkName(results, fr)).toBe(
      "4 paliers atteints : Dark Souls, complet ; Metroidvania, or ; Roguelike, argent ; Les Pépites, bronze. Voir les sets en cours.",
    )
    expect(foldedLinkName(results, en)).toBe(
      "4 tiers reached: Dark Souls, complete; Metroidvania, gold; Roguelike, silver; Les Pépites, bronze. View sets in progress.",
    )
  })
})

describe("celebrationAnnouncement", () => {
  it("speaks a tier reached and a set completed with their counts", () => {
    expect(celebrationAnnouncement(celebrationResults([reached("Roguelike", "silver", 16, 62)]), fr, NBSP)).toBe(
      "Palier argent atteint : Roguelike, 16 cartes sur 62.",
    )
    expect(celebrationAnnouncement(celebrationResults([reached("Roguelike", "complete", 1062, 1062)]), fr, NBSP)).toBe(
      `Set complet : Roguelike, 1${NBSP}062 cartes sur 1${NBSP}062.`,
    )
  })

  it("speaks up to three results in one message, in their order", () => {
    const results = celebrationResults([reached("Roguelike", "bronze", 7, 62), reached("Dark Souls", "complete", 3, 3, "franchise")])

    expect(celebrationAnnouncement(results, fr, NBSP)).toBe(
      "Set complet : Dark Souls, 3 cartes sur 3. Palier bronze atteint : Roguelike, 7 cartes sur 62.",
    )
  })

  it("speaks a folded celebration as one list of sets and tiers", () => {
    const results = celebrationResults([
      reached("Roguelike", "silver", 16, 62),
      reached("Metroidvania", "gold", 39, 77),
      reached("Cosy", "bronze", 6, 54),
      reached("Dark Souls", "complete", 3, 3, "franchise"),
    ])

    expect(celebrationAnnouncement(results, fr, NBSP)).toBe(
      "4 paliers atteints : Dark Souls, complet ; Metroidvania, or ; Roguelike, argent ; Cosy, bronze.",
    )
  })

  it("starts an English message with a capital and reads \"cards out of\"", () => {
    expect(celebrationAnnouncement(celebrationResults([reached("Roguelike", "silver", 16, 62)]), en, ",")).toBe(
      "Silver tier reached: Roguelike, 16 cards out of 62.",
    )
  })
})
