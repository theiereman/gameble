// The card types the pack reveal shares with the server (AD-16). Card faces
// are rendered on the server only (CardComponent); the island receives
// them as HTML.

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

/** CardStrings#to_props: every word of a card's back, resolved on the server. */
export type CardStrings = {
  rarityNames: Record<Rarity, string>
  faceDown: string
  faceDownByRarity: Record<Rarity, string>
}
