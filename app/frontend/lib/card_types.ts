// The card types the booster screen shares with the server. Card
// faces are rendered on the server only (CardComponent); the screen
// receives them as HTML.

/** Catalog::Rarity::TIERS code names, from the most common. */
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export const RARITIES: readonly Rarity[] = ["common", "uncommon", "rare", "epic", "legendary"]
