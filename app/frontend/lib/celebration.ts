import { formatNumber, t, type Template } from "./i18n"
import { SET_TIERS, type OpeningSetTier, type SetThreshold, type SetTierName } from "./opening"

export const FOLD_ABOVE = 3

export type CelebrationStrings = {
  tierTitle: string
  completeTitle: string
  count: string
  tiers: Record<SetTierName, string>
  folded: Template
  foldedLead: string
  foldedHint: string
  openSet: string
  openInProgress: string
  position: string
  next: string
  announceTier: string
  announceComplete: string
  announceFolded: Template
  announceItem: string
  announceSeparator: string
  spokenTiers: Record<SetTierName, string>
}

export const RANKS = ["novice", "apprentice", "adept", "expert", "master"] as const satisfies readonly SetTierName[]
export type Rank = (typeof RANKS)[number]

export const isRank = (tier: SetTierName): tier is Rank => (RANKS as readonly SetTierName[]).includes(tier)

export type CelebrationResult = {
  key: string
  name: string
  url: string
  tier: SetTierName
  required: number
  owned: number
  total: number
  before: number
  crossed: SetTierName[]
  thresholds: SetThreshold[]
}

const METAL_NOTCHES: Partial<Record<SetTierName, number>> = { bronze: 1, silver: 2, gold: 3 }

export const notchCount = (tier: SetTierName): number => METAL_NOTCHES[tier] ?? 0

const tieBreak = (tier: SetTierName): number => SET_TIERS.indexOf(tier)

function standsAbove(a: { tier: SetTierName; required: number; total: number }, b: { tier: SetTierName; required: number; total: number }): number {
  const completes = Number(a.tier === "complete") - Number(b.tier === "complete")
  const share = (row: { required: number; total: number }): number => (row.total > 0 ? row.required / row.total : 1)
  return completes || share(a) - share(b) || tieBreak(a.tier) - tieBreak(b.tier)
}

export function celebrationResults(setTiers: readonly OpeningSetTier[]): CelebrationResult[] {
  const bySet = new Map<string, OpeningSetTier[]>()
  for (const reached of setTiers) {
    const key = `${reached.kind}:${reached.key}`
    bySet.set(key, [...(bySet.get(key) ?? []), reached])
  }
  return [...bySet.entries()]
    .map(([key, rows]) => resultOf(key, rows))
    .sort((a, b) => standsAbove(b, a))
}

function resultOf(key: string, rows: readonly OpeningSetTier[]): CelebrationResult {
  const highest = rows.reduce((kept, row) => (standsAbove(row, kept) > 0 ? row : kept))
  const lowestRequired = Math.min(...rows.map((row) => row.required))
  const byRequired = [...rows].sort((a, b) => a.required - b.required || tieBreak(a.tier) - tieBreak(b.tier))
  return {
    key,
    name: highest.name,
    url: highest.url,
    tier: highest.tier,
    required: highest.required,
    owned: Math.max(...rows.map((row) => row.held)),
    total: highest.total,
    before: Math.max(0, lowestRequired - 1),
    crossed: [...new Set(byRequired.map((row) => row.tier))],
    thresholds: [...highest.thresholds].sort((a, b) => a.required - b.required || tieBreak(a.tier) - tieBreak(b.tier)),
  }
}

export function restoredCelebration(setTiers: readonly OpeningSetTier[], marked: boolean): CelebrationResult[] | null {
  if (!marked) return null
  const results = celebrationResults(setTiers)
  return results.length > 0 ? results : null
}

export const folded = (results: readonly CelebrationResult[]): boolean => results.length > FOLD_ABOVE

export const resultTitle = (result: CelebrationResult, strings: CelebrationStrings): string =>
  result.tier === "complete" ? strings.completeTitle : t(strings.tierTitle, { tier: strings.tiers[result.tier] })

export function countParts(result: CelebrationResult, strings: CelebrationStrings, delimiter: string): { before: string; owned: string; rest: string } {
  const [, rest = ""] = strings.count.split("%{owned}")
  return {
    before: formatNumber(result.before, delimiter),
    owned: formatNumber(result.owned, delimiter),
    rest: t(rest, { total: formatNumber(result.total, delimiter) }),
  }
}

export const tiersReached = (results: readonly CelebrationResult[]): number => results.reduce((count, result) => count + result.crossed.length, 0)

export const foldedTitle = (results: readonly CelebrationResult[], strings: CelebrationStrings): string =>
  t(strings.folded, { count: tiersReached(results) })

export function foldedSubline(results: readonly CelebrationResult[], strings: CelebrationStrings): { lead: string; set: string; tier: string } {
  const [highest] = results
  return { lead: strings.foldedLead, set: highest.name, tier: strings.tiers[highest.tier] }
}

export const MARK_START = 80
export const MARK_GAP = 90

export function foldedMarks(results: readonly CelebrationResult[]): { tier: SetTierName; lightAt: number }[] {
  const tiers = [...new Set(results.map((result) => result.tier))].reverse()
  return tiers.map((tier, lit) => ({ tier, lightAt: MARK_START + MARK_GAP * lit }))
}

export const MIN_SHARE = 0.015

export const FILL_START = 80
export const FILL_MS = 380
export const FILL_BEFORE_SHARE = 0.45

export const LANDS_AT = 440

export function gaugeFractions(result: CelebrationResult): { from: number; to: number } {
  if (result.total <= 0) return { from: 0, to: 1 }
  const from = Math.min(1, result.before / result.total)
  return { from, to: Math.min(1, Math.max(result.owned / result.total, from + MIN_SHARE)) }
}

export function fillReaches(at: number, { from, to }: { from: number; to: number }): number {
  const beforeMs = FILL_MS * FILL_BEFORE_SHARE
  if (at <= from) return Math.round(FILL_START + (from > 0 ? beforeMs * (at / from) : 0))
  const share = to > from ? Math.min(1, (at - from) / (to - from)) : 1
  return Math.round(FILL_START + beforeMs + (FILL_MS - beforeMs) * share)
}

export type TickState = "solid" | "crossed" | "pending"

export type GaugeTick = { tier: SetTierName; at: number; state: TickState; lightAt: number | null }

export function gaugeTicks(result: CelebrationResult): GaugeTick[] {
  if (result.tier === "complete" || result.total <= 0) return []
  const fill = gaugeFractions(result)
  return result.thresholds.map(({ tier, required }) => {
    const at = Math.min(1, required / result.total)
    if (required > result.owned) return { tier, at, state: "pending", lightAt: null }
    if (!result.crossed.includes(tier)) return { tier, at, state: "solid", lightAt: null }
    if (tier === result.tier) return { tier, at, state: "crossed", lightAt: LANDS_AT }
    return { tier, at, state: "crossed", lightAt: Math.min(LANDS_AT, fillReaches(at, fill)) }
  })
}

export type Juice = { tickSparks: number; endSparks: number; ribbonSparks: number; glosses: number; glints: boolean }

const JUICE: Record<SetTierName, Juice> = {
  bronze: { tickSparks: 0, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false },
  silver: { tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 1, glints: false },
  gold: { tickSparks: 12, endSparks: 0, ribbonSparks: 8, glosses: 2, glints: true },
  novice: { tickSparks: 0, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false },
  apprentice: { tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 0, glints: false },
  adept: { tickSparks: 6, endSparks: 0, ribbonSparks: 0, glosses: 1, glints: false },
  expert: { tickSparks: 6, endSparks: 0, ribbonSparks: 8, glosses: 1, glints: false },
  master: { tickSparks: 6, endSparks: 0, ribbonSparks: 8, glosses: 1, glints: true },
  complete: { tickSparks: 0, endSparks: 18, ribbonSparks: 14, glosses: 2, glints: true },
}

export const juice = (tier: SetTierName): Juice => JUICE[tier]

const SPARK_REACH = [1.2, 0.85, 1.05]

export function sparkOffsets(count: number, radius: number): { dx: number; dy: number; k: number }[] {
  return Array.from({ length: count }, (_, index) => {
    const angle = (index / count) * Math.PI * 2 + (index % 2 ? 0.22 : -0.12)
    const reach = radius * SPARK_REACH[index % 3]
    return {
      dx: Math.round((Math.cos(angle) * reach) / 2) * 2 || 0,
      dy: Math.round((Math.sin(angle) * reach * 0.8) / 2) * 2 || 0,
      k: index % 3,
    }
  })
}

const sentence = (text: string): string => text.charAt(0).toUpperCase() + text.slice(1)

export function resultMessage(result: CelebrationResult, strings: CelebrationStrings, delimiter: string): string {
  const vars = { set: result.name, tier: strings.spokenTiers[result.tier], owned: formatNumber(result.owned, delimiter), total: formatNumber(result.total, delimiter) }
  return sentence(t(result.tier === "complete" ? strings.announceComplete : strings.announceTier, vars))
}

export function foldedMessage(results: readonly CelebrationResult[], strings: CelebrationStrings): string {
  const list = results.map((result) => t(strings.announceItem, { set: result.name, tier: strings.spokenTiers[result.tier] })).join(strings.announceSeparator)
  return sentence(t(strings.announceFolded, { count: tiersReached(results), list }))
}

export function celebrationAnnouncement(results: readonly CelebrationResult[], strings: CelebrationStrings, delimiter: string): string {
  if (folded(results)) return foldedMessage(results, strings)
  return results.map((result) => resultMessage(result, strings, delimiter)).join(" ")
}

export const resultLinkName = (result: CelebrationResult, strings: CelebrationStrings, delimiter: string): string =>
  `${resultMessage(result, strings, delimiter)} ${strings.openSet}`

export const foldedLinkName = (results: readonly CelebrationResult[], strings: CelebrationStrings): string =>
  `${foldedMessage(results, strings)} ${strings.openInProgress}`
