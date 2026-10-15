import { describe, expect, it } from "vitest"
import {
  celebrationAnnouncement,
  celebrationResults,
  folded,
  foldedTitle,
  nextResult,
  notchCount,
  resultCount,
  resultTitle,
  type CelebrationStrings,
} from "./celebration"
import type { OpeningSetTier } from "./opening"

// As config/locales/fr.yml words them.
const fr: CelebrationStrings = {
  tierTitle: "PALIER %{tier}",
  completeTitle: "SET COMPLET",
  count: "%{owned}/%{total}",
  tiers: { bronze: "BRONZE", silver: "ARGENT", gold: "OR" },
  folded: { zero: "%{count} PALIER ATTEINT", one: "%{count} PALIER ATTEINT", other: "%{count} PALIERS ATTEINTS" },
  position: "%{index} / %{count}",
  next: "Résultat suivant",
  announceTier: "Palier %{tier} atteint : %{set}, %{owned} cartes sur %{total}.",
  announceComplete: "Set complet : %{set}, %{owned} cartes sur %{total}.",
  announceFolded: { zero: "%{count} palier atteint : %{list}.", one: "%{count} palier atteint : %{list}.", other: "%{count} paliers atteints : %{list}." },
  announceItem: "%{set}, %{tier}",
  announceSeparator: " ; ",
  spokenTiers: { bronze: "bronze", silver: "argent", gold: "or", complete: "complet" },
}

const NBSP = " "

const reached = (name: string, tier: OpeningSetTier["tier"], required: number, total: number, kind = "theme"): OpeningSetTier => ({
  kind,
  key: name.toLowerCase().replace(/\s+/g, "-"),
  name,
  tier,
  required,
  total,
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
})

describe("the results as shown", () => {
  it("titles a tier by its name and a completed set as SET COMPLET, with its count", () => {
    const [complete, silver] = celebrationResults([reached("Roguelike", "silver", 16, 62), reached("Dark Souls", "complete", 3, 3, "franchise")])

    expect(resultTitle(silver, fr)).toBe("PALIER ARGENT")
    expect(resultCount(silver, fr, NBSP)).toBe("16/62")
    expect(resultTitle(complete, fr)).toBe("SET COMPLET")
    expect([notchCount("bronze"), notchCount("silver"), notchCount("gold"), notchCount("complete")]).toEqual([1, 2, 3, 0])
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

  it("starts an English message with a capital", () => {
    const en = { ...fr, announceTier: "%{tier} tier reached: %{set}, %{owned} cards of %{total}.", spokenTiers: { ...fr.spokenTiers, silver: "silver" } }
    expect(celebrationAnnouncement(celebrationResults([reached("Roguelike", "silver", 16, 62)]), en, ",")).toBe(
      "Silver tier reached: Roguelike, 16 cards of 62.",
    )
  })
})
