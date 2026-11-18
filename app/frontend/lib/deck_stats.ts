import type { Percentiles } from "./deck_collection_order"

// tier: the percentile's tens, 0 (the lowest) to 9 (the highest), one colour step each along red, orange, yellow, green.
export type Bar = { stat: string; value: number; tier: number; trump: boolean }

export function barsOf(percentiles: Percentiles, trump: string): Bar[] {
  return Object.entries(percentiles).flatMap(([stat, percentile]) => {
    if (typeof percentile !== "number") return []
    const value = Math.min(Math.max(Math.round(percentile), 0), 99)
    return [{ stat, value, tier: Math.floor(value / 10), trump: stat === trump }]
  })
}
