import type { Rarity } from "./card_types"

export type ImpactStyle = "light" | "medium" | "heavy"

export const IMPACTS: Record<Rarity, ImpactStyle> = {
  common: "light",
  uncommon: "light",
  rare: "medium",
  epic: "heavy",
  legendary: "heavy",
}

export const TOUCH_IMPACT: ImpactStyle = "light"

export const CHARGE_IMPACTS: Record<1 | 2 | 3, ImpactStyle> = { 1: "light", 2: "medium", 3: "heavy" }

export const BURST_IMPACT: ImpactStyle = "heavy"

export const DEAL_IMPACT: ImpactStyle = "medium"

export type PushGrant = { token: string; platform: string }

export function pushGrant(data: Record<string, unknown>): PushGrant | null {
  const { token, platform } = data
  return typeof token === "string" && token !== "" && typeof platform === "string" ? { token, platform } : null
}
