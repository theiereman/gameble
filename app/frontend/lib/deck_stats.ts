import type { Percentiles } from "./deck_collection_order"

export type Tier = "lowest" | "low" | "mid" | "high" | "highest"
export type Bar = { stat: string; value: number; tier: Tier; trump: boolean }

const tierOf = (value: number): Tier =>
  value >= 90 ? "highest" : value >= 70 ? "high" : value <= 10 ? "lowest" : value <= 30 ? "low" : "mid"

export function barsOf(percentiles: Percentiles, trump: string): Bar[] {
  return Object.entries(percentiles).flatMap(([stat, percentile]) => {
    if (typeof percentile !== "number") return []
    const value = Math.min(Math.max(Math.round(percentile), 0), 99)
    return [{ stat, value, tier: tierOf(value), trump: stat === trump }]
  })
}
