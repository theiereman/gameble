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
  isRank,
  juice,
  notchCount,
  resultLinkName,
  resultTitle,
  restoredCelebration,
  sparkOffsets,
  type CelebrationStrings,
  type Rank,
} from "./celebration"
import type { OpeningSetTier, SetThreshold, SetTierName } from "./opening"

// As config/locales/fr.yml words them.
const fr: CelebrationStrings = {
  tierTitle: "PALIER %{tier}",
  completeTitle: "SET COMPLET",
  count: "%{owned}/%{total}",
  tiers: {
    bronze: "BRONZE",
    silver: "ARGENT",
    gold: "OR",
    novice: "NOVICE",
    apprentice: "APPRENTI",
    adept: "ADEPTE",
    expert: "EXPERT",
    master: "MAÎTRE",
    complete: "COMPLET",
  },
  folded: { zero: "%{count} PALIER ATTEINT", one: "%{count} PALIER ATTEINT", other: "%{count} PALIERS ATTEINTS" },
  foldedLead: "dont",
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
  spokenTiers: {
    bronze: "bronze",
    silver: "argent",
    gold: "or",
    novice: "novice",
    apprentice: "apprenti",
    adept: "adepte",
    expert: "expert",
    master: "maître",
    complete: "complet",
  },
}

const en: CelebrationStrings = {
  ...fr,
  tierTitle: "%{tier} TIER",
  completeTitle: "SET COMPLETE",
  tiers: {
    bronze: "BRONZE",
    silver: "SILVER",
    gold: "GOLD",
    novice: "NOVICE",
    apprentice: "APPRENTICE",
    adept: "ADEPT",
    expert: "EXPERT",
    master: "MASTER",
    complete: "COMPLETE",
  },
  folded: { one: "%{count} TIER REACHED", other: "%{count} TIERS REACHED" },
  foldedLead: "incl.",
  foldedHint: "IN PROGRESS",
  openSet: "View set.",
  openInProgress: "View sets in progress.",
  next: "Next result",
  announceTier: "%{tier} tier reached: %{set}, %{owned} cards out of %{total}.",
  announceComplete: "Set complete: %{set}, %{owned} cards out of %{total}.",
  announceFolded: { one: "%{count} tier reached: %{list}.", other: "%{count} tiers reached: %{list}." },
  announceSeparator: "; ",
  spokenTiers: {
    bronze: "bronze",
    silver: "silver",
    gold: "gold",
    novice: "novice",
    apprentice: "apprentice",
    adept: "adept",
    expert: "expert",
    master: "master",
    complete: "complete",
  },
}

const NBSP = " "

const slug = (name: string): string => name.toLowerCase().replace(/\s+/g, "-")

const METAL_SHARES = [
  ["bronze", 0.1],
  ["silver", 0.25],
  ["gold", 0.5],
] as const

// Catalog::TierTable's rows: ranks counted from the top by the set's size.
const RANK_ROWS: [number, [Rank, number][]][] = [
  [200, [["novice", 0.1], ["apprentice", 0.25], ["adept", 0.5], ["expert", 0.75], ["master", 0.9]]],
  [60, [["apprentice", 0.1], ["adept", 0.25], ["expert", 0.5], ["master", 0.75]]],
  [20, [["adept", 0.25], ["expert", 0.5], ["master", 0.75]]],
  [10, [["expert", 1 / 3], ["master", 2 / 3]]],
  [5, [["master", 0.5]]],
  [0, []],
]

/** The thresholds a set of `total` cards was published with: the metals of earlier seasons, or the ranks. */
function thresholdsOf(tier: SetTierName, total: number): SetThreshold[] {
  const shares = isRank(tier) ? RANK_ROWS.find(([minimum]) => total >= minimum)![1] : METAL_SHARES
  return shares.map(([name, share]) => ({ tier: name, required: Math.ceil(share * total) }))
}

const reached = (name: string, tier: OpeningSetTier["tier"], required: number, total: number, kind = "theme", held = required): OpeningSetTier => ({
  kind,
  key: slug(name),
  name,
  tier,
  required,
  held,
  total,
  thresholds: thresholdsOf(tier, total),
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

  it("puts a completed set first, then the larger shares of their sets, then the sets in the order they came", () => {
    const results = celebrationResults([
      reached("Roguelike", "bronze", 7, 62),
      reached("Pirates", "gold", 9, 18),
      reached("Cosy", "bronze", 6, 54),
      reached("Dark Souls", "complete", 3, 3, "franchise"),
      reached("Metroidvania", "gold", 39, 77),
      reached("Horror", "gold", 9, 18),
    ])

    expect(results.map((result) => result.name)).toEqual(["Dark Souls", "Metroidvania", "Pirates", "Horror", "Roguelike", "Cosy"])
  })

  it("ranks results across sets by the share of the set their tier stands for, whatever its name", () => {
    const results = celebrationResults([
      reached("Roguelike", "adept", 16, 62),
      reached("Dark Souls", "expert", 4, 10, "franchise"),
      reached("Hades", "master", 4, 7, "franchise"),
    ])

    expect(results.map(({ name, tier }) => [name, tier])).toEqual([
      ["Hades", "master"],
      ["Dark Souls", "expert"],
      ["Roguelike", "adept"],
    ])
  })

  it("keeps a ranked set's highest rank and its crossed ranks in the order of the counts they ask", () => {
    const [result] = celebrationResults([reached("Roguelike", "expert", 31, 62), reached("Roguelike", "adept", 16, 62)])

    expect([result.tier, result.owned, result.before, result.crossed]).toEqual(["expert", 31, 15, ["adept", "expert"]])
  })

  it("counts the cards held, beyond the count the tier asks", () => {
    const [result] = celebrationResults([reached("Roguelike", "apprentice", 16, 62, "theme", 18)])

    expect([result.tier, result.owned, result.before]).toEqual(["apprentice", 18, 15])
    expect(gaugeTicks(result).find(({ tier }) => tier === "apprentice")?.state).toBe("crossed")
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

  it("titles a rank by its name, without notches", () => {
    const [master] = celebrationResults([reached("Hades", "master", 4, 7, "franchise")])

    expect(resultTitle(master, fr)).toBe("PALIER MAÎTRE")
    expect(resultTitle(master, en)).toBe("MASTER TIER")
    expect(notchCount("master")).toBe(0)
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

  it("counts every tier crossed in the folded line, two in one set counting two", () => {
    const results = celebrationResults([
      ...["A", "B", "C"].map((name) => reached(name, "bronze", 2, 20)),
      reached("D", "silver", 10, 20),
      reached("D", "bronze", 2, 20),
    ])

    expect(foldedTitle(results, fr)).toBe("5 PALIERS ATTEINTS")
    expect(celebrationAnnouncement(results, fr, NBSP)).toMatch(/^5 paliers atteints : /)
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

  it("sets an earlier season's metal ticks at the set's own thresholds", () => {
    const [silver] = celebrationResults([reached("Roguelike", "silver", 16, 62)])
    expect(gaugeTicks(silver).map(({ tier, at }) => [tier, at])).toEqual([
      ["bronze", 7 / 62],
      ["silver", 16 / 62],
      ["gold", 31 / 62],
    ])
  })

  it("lights both ticks of a double crossing, the lower as the fill passes it, the result's own last", () => {
    const [double] = celebrationResults([reached("Cosy", "silver", 2, 7), reached("Cosy", "bronze", 1, 7)])
    const [bronze, silver, gold] = gaugeTicks(double)

    expect([bronze.state, silver.state, gold.state]).toEqual(["crossed", "crossed", "pending"])
    expect(bronze.lightAt).toBe(fillReaches(1 / 7, gaugeFractions(double)))
    expect(silver.lightAt).toBe(LANDS_AT)
    expect(bronze.lightAt!).toBeLessThan(silver.lightAt!)
  })

  it("draws a ranked set's ticks at its thresholds: adept of 40 cards crossed, expert and master ahead", () => {
    const [adept] = celebrationResults([reached("Roguelike", "adept", 10, 40)])

    expect(gaugeTicks(adept)).toEqual([
      { tier: "adept", at: 0.25, state: "crossed", lightAt: LANDS_AT },
      { tier: "expert", at: 0.5, state: "pending", lightAt: null },
      { tier: "master", at: 0.75, state: "pending", lightAt: null },
    ])
  })

  it("keeps a rank reached before the capsule solid, and lights each rank it crosses", () => {
    const [master] = celebrationResults([reached("Les OVNI", "expert", 188, 250, "ufo"), reached("Les OVNI", "master", 225, 250, "ufo")])

    expect(gaugeTicks(master).map(({ tier, state }) => [tier, state])).toEqual([
      ["novice", "solid"],
      ["apprentice", "solid"],
      ["adept", "solid"],
      ["expert", "crossed"],
      ["master", "crossed"],
    ])
  })

  it("draws one tick for a set of seven cards, none for a set too small for ranks", () => {
    const [master] = celebrationResults([reached("Dark Souls", "master", 4, 7, "franchise")])
    expect(gaugeTicks(master).map(({ tier, at, state }) => [tier, at, state])).toEqual([["master", 4 / 7, "crossed"]])

    const [small] = celebrationResults([{ ...reached("Hollow Knight", "novice", 1, 3, "franchise"), thresholds: [] }])
    expect(gaugeTicks(small)).toEqual([])
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

  it("draws a rank result's ticks from its own ranks, never the metals", () => {
    const [adept] = celebrationResults([reached("Roguelike", "adept", 16, 62)])
    expect(gaugeTicks(adept).map(({ tier }) => tier)).toEqual(["apprentice", "adept", "expert", "master"])
  })
})

describe("the juice", () => {
  it("grows with the tier", () => {
    expect(juice("bronze")).toEqual({ tickSparks: 0, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false })
    expect(juice("silver")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 1, glints: false })
    expect(juice("gold")).toEqual({ tickSparks: 12, endSparks: 0, ribbonSparks: 8, glosses: 2, glints: true })
    expect(juice("complete")).toEqual({ tickSparks: 0, endSparks: 18, ribbonSparks: 14, glosses: 2, glints: true })
  })

  it("adds one detail per rank to the rank below", () => {
    expect(juice("novice")).toEqual({ tickSparks: 0, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false })
    expect(juice("apprentice")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false })
    expect(juice("adept")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 1, glints: false })
    expect(juice("expert")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 8, glosses: 1, glints: false })
    expect(juice("master")).toEqual({ tickSparks: 6, endSparks: 0, ribbonSparks: 8, glosses: 1, glints: true })
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

  it("lights the mark of each result's tier, from the lowest result to the highest", () => {
    expect(foldedMarks(four())).toEqual([
      { tier: "bronze", lightAt: 80 },
      { tier: "silver", lightAt: 170 },
      { tier: "gold", lightAt: 260 },
      { tier: "complete", lightAt: 350 },
    ])
  })

  it("lights the ranks of its results in turn: novice, adept, expert, master", () => {
    const ranks = celebrationResults([
      reached("Dark Souls", "master", 4, 7, "franchise"),
      reached("Metroidvania", "expert", 50, 100),
      reached("Roguelike", "adept", 10, 40),
      reached("Les OVNI", "novice", 25, 250, "ufo"),
    ])

    expect(foldedMarks(ranks)).toEqual([
      { tier: "novice", lightAt: 80 },
      { tier: "adept", lightAt: 170 },
      { tier: "expert", lightAt: 260 },
      { tier: "master", lightAt: 350 },
    ])
  })

  it("places a tier shared by several results by its highest one", () => {
    const results = celebrationResults([
      reached("Les OVNI", "adept", 125, 250, "ufo"),
      reached("Supergiant", "expert", 4, 12, "studio"),
      reached("Roguelike", "adept", 10, 40),
      reached("Metroidvania", "apprentice", 10, 100),
    ])

    expect(results.map(({ tier }) => tier)).toEqual(["adept", "expert", "adept", "apprentice"])
    expect(foldedMarks(results).map(({ tier }) => tier)).toEqual(["apprentice", "expert", "adept"])
  })

  it("shows one mark per tier, however many results share it", () => {
    const bronzes = celebrationResults(["A", "B", "C", "D"].map((name) => reached(name, "bronze", 2, 20)))
    expect(foldedMarks(bronzes)).toEqual([{ tier: "bronze", lightAt: 80 }])

    const ranks = celebrationResults(["A", "B", "C"].map((name) => reached(name, "adept", 5, 20)).concat(reached("D", "complete", 3, 3)))
    expect(foldedMarks(ranks)).toEqual([
      { tier: "adept", lightAt: 80 },
      { tier: "complete", lightAt: 170 },
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
