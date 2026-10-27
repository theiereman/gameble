// The card types the booster screen shares with the server, which renders card faces as HTML.

/** Catalog::Rarity::TIERS code names, from the most common. */
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export const RARITIES: readonly Rarity[] = ["common", "uncommon", "rare", "epic", "legendary"]
