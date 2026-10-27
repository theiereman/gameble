import type { Rarity } from "./card_types"

export type Intent<Detail> = CustomEvent<Detail>

export type Fragments = Readonly<{
  face: (index: number) => DocumentFragment | null
  icon: (tier: Rarity) => DocumentFragment | null
}>

export const BANNER_TIERS: readonly Rarity[] = ["epic", "legendary"]

export const opensElsewhere = (event: Event): boolean =>
  event instanceof MouseEvent && (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
