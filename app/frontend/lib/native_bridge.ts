import type { Rarity } from "./card_types"

export type ImpactStyle = "light" | "medium" | "heavy"

export const IMPACTS: Record<Rarity, ImpactStyle> = {
  common: "light",
  uncommon: "light",
  rare: "medium",
  epic: "heavy",
  legendary: "heavy",
}

export type PushGrant = { token: string; platform: string }

export function pushGrant(data: Record<string, unknown>): PushGrant | null {
  const { token, platform } = data
  return typeof token === "string" && token !== "" && typeof platform === "string" ? { token, platform } : null
}
