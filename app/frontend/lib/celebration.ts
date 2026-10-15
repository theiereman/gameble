// The set celebration after an opening: the results the island shows once
// the hand is complete, one per set at the highest tier the opening
// reached, and the one message the live region speaks for them. Pure: no
// DOM.
import { formatNumber, t, type Template } from "./i18n"
import type { OpeningSetTier, SetTierName } from "./opening"

/** More results than this fold into one line, "n PALIERS ATTEINTS". */
export const FOLD_ABOVE = 3

export type CelebrationStrings = {
  tierTitle: string
  completeTitle: string
  count: string
  tiers: Record<Exclude<SetTierName, "complete">, string>
  folded: Template
  position: string
  next: string
  announceTier: string
  announceComplete: string
  announceFolded: Template
  announceItem: string
  announceSeparator: string
  spokenTiers: Record<SetTierName, string>
}

/** A set's result: its name, the highest tier the opening reached, its cards at that tier over the set's. */
export type CelebrationResult = {
  key: string
  name: string
  tier: SetTierName
  owned: number
  total: number
}

const RANK: Record<SetTierName, number> = { bronze: 1, silver: 2, gold: 3, complete: 4 }

/** The notches a tier mark carries: one to three, none for a completed set. */
export const notchCount = (tier: SetTierName): number => (tier === "complete" ? 0 : RANK[tier])

/** One result per set (by kind and key), at its highest tier; the highest tiers first, then by name. */
export function celebrationResults(setTiers: readonly OpeningSetTier[], locale?: string): CelebrationResult[] {
  const bySet = new Map<string, OpeningSetTier>()
  for (const reached of setTiers) {
    const key = `${reached.kind}:${reached.key}`
    const kept = bySet.get(key)
    if (!kept || RANK[reached.tier] > RANK[kept.tier]) bySet.set(key, reached)
  }
  return [...bySet.entries()]
    .map(([key, { name, tier, required, total }]) => ({ key, name, tier, owned: required, total }))
    .sort((a, b) => RANK[b.tier] - RANK[a.tier] || a.name.localeCompare(b.name, locale))
}

export const folded = (results: readonly CelebrationResult[]): boolean => results.length > FOLD_ABOVE

/** The result after `index` on the phone, back to the first after the last. */
export const nextResult = (index: number, count: number): number => (count > 0 ? (index + 1) % count : 0)

/** "PALIER ARGENT" or "SET COMPLET". */
export const resultTitle = (result: CelebrationResult, strings: CelebrationStrings): string =>
  result.tier === "complete" ? strings.completeTitle : t(strings.tierTitle, { tier: strings.tiers[result.tier] })

/** "16/62". */
export const resultCount = (result: CelebrationResult, strings: CelebrationStrings, delimiter: string): string =>
  t(strings.count, { owned: formatNumber(result.owned, delimiter), total: formatNumber(result.total, delimiter) })

/** "4 PALIERS ATTEINTS". */
export const foldedTitle = (results: readonly CelebrationResult[], strings: CelebrationStrings): string =>
  t(strings.folded, { count: results.length })

const sentence = (text: string): string => text.charAt(0).toUpperCase() + text.slice(1)

/** The live region's one message for the results. */
export function celebrationAnnouncement(results: readonly CelebrationResult[], strings: CelebrationStrings, delimiter: string): string {
  if (folded(results)) {
    const list = results.map((result) => t(strings.announceItem, { set: result.name, tier: strings.spokenTiers[result.tier] })).join(strings.announceSeparator)
    return sentence(t(strings.announceFolded, { count: results.length, list }))
  }
  return results
    .map((result) => {
      const vars = { set: result.name, tier: strings.spokenTiers[result.tier], owned: formatNumber(result.owned, delimiter), total: formatNumber(result.total, delimiter) }
      return sentence(t(result.tier === "complete" ? strings.announceComplete : strings.announceTier, vars))
    })
    .join(" ")
}
