import { handPutAway } from "./booster_bank"
import type { BoosterState, BoosterStatus, Layout, OpeningOutcome, RevealAllStep, TierCounts } from "./booster_types"
import type { Rarity } from "./card_types"

export function layoutFor(phone: boolean, narrow: boolean): Layout {
  return phone ? "phone" : narrow ? "narrow" : "wide"
}

export function faceSize(layout: Layout): "xl" | "s" | "m" {
  return layout === "phone" ? "xl" : layout === "narrow" ? "s" : "m"
}

const REVEALING_STATUSES: readonly BoosterStatus[] = ["arming", "ejecting", "inventory", "legendarySignal"]

export function revealingOpening(status: BoosterStatus): boolean {
  return REVEALING_STATUSES.includes(status)
}

export function planRevealAll(tiers: readonly Rarity[], revealed: readonly boolean[]): RevealAllStep[] {
  return tiers.flatMap((tier, index) => (revealed[index] ? [] : [{ index, wait: tier === "legendary" ? "full" : "gap" } as const]))
}

export function keyAfter(outcome: OpeningOutcome, key: string): string | null {
  if (outcome.kind === "failed") return key
  if (outcome.kind === "refused" && outcome.code === "throttled") return key
  return null
}

export const NO_COUNTS: TierCounts = { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 }

export function countsAfterReveal(counts: TierCounts, tier: Rarity): TierCounts {
  return { ...counts, [tier]: counts[tier] + 1 }
}

export function topOfPile(revealed: readonly boolean[], stored: readonly boolean[]): number | null {
  const index = revealed.findIndex((_, position) => !stored[position])
  return index === -1 ? null : index
}

export function zoomNeighbour(stored: readonly boolean[], index: number, step: -1 | 1): number | null {
  for (let position = index + step; position >= 0 && position < stored.length; position += step) {
    if (stored[position]) return position
  }
  return null
}

export function storedAfterRebuild(revealed: readonly boolean[], stored: readonly boolean[], layout: Layout): boolean[] {
  return layout === "phone" ? revealed.map((shown, index) => shown || (stored[index] ?? false)) : revealed.map(() => false)
}

export const allRevealed = (state: BoosterState): boolean => state.revealed.length > 0 && state.revealed.every(Boolean)

export const handDone = (state: BoosterState): boolean => handPutAway(state.layout, state.revealed, state.stored)
