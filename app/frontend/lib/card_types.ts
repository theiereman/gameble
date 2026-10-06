// The card types the booster island shares with the server (AD-16). Card
// faces are rendered on the server only (CardComponent); the island
// receives them as HTML.

/** Catalog::Rarity::TIERS code names, from the most common. */
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export const RARITIES: readonly Rarity[] = ["common", "uncommon", "rare", "epic", "legendary"]
