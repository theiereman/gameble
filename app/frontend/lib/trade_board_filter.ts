import type { Rarity } from "./card_types"
import type { Side } from "./trade_board"

function fold(text: string): string {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().trim()
}

export const CHIPS = {
  friend: ["duplicates", "missing", "shared"],
  own: ["duplicates", "missing", "available"],
} as const satisfies Record<Side, readonly string[]>

export type Chip = (typeof CHIPS)[Side][number]

export type FilterableCard = {
  title: string
  rarity: Rarity
  copies: number
  otherCopies: number
  max: number
  genre: string
  goals: readonly string[]
}

const CHIP_MATCHES: Record<Chip, (card: FilterableCard) => boolean> = {
  duplicates: (card) => card.copies >= 2,
  missing: (card) => card.otherCopies === 0,
  shared: (card) => card.otherCopies > 0,
  available: (card) => card.max >= 1,
}

export type SideFilter = {
  query: string
  rarities: readonly Rarity[]
  chips: readonly Chip[]
  genres: readonly string[]
  goals: readonly string[]
}

export const EMPTY_FILTER: SideFilter = { query: "", rarities: [], chips: [], genres: [], goals: [] }

export function moreChips({ genres, goals }: SideFilter): number {
  return genres.length + goals.length
}

export function activeChips(filter: SideFilter): number {
  return filter.rarities.length + filter.chips.length + moreChips(filter)
}

export function filtering(filter: SideFilter): boolean {
  return filter.query.trim() !== "" || activeChips(filter) > 0
}

export type PickerFilters = { filter: SideFilter; folded: boolean; moreFolded: boolean }

export const FRESH_PICKER_FILTERS: PickerFilters = { filter: EMPTY_FILTER, folded: true, moreFolded: true }

export function withFilter(state: PickerFilters, filter: SideFilter): PickerFilters {
  return { ...state, filter }
}

export function clearedFilters(state: PickerFilters): PickerFilters {
  return withFilter(state, EMPTY_FILTER)
}

export function toggledFold(state: PickerFilters): PickerFilters {
  return { ...state, folded: !state.folded }
}

export function toggledMoreFold(state: PickerFilters): PickerFilters {
  return { ...state, moreFolded: !state.moreFolded }
}

const anyOf = <Value>(chosen: readonly Value[], matches: (value: Value) => boolean): boolean =>
  chosen.length === 0 || chosen.some(matches)

export function filterCards<Card extends FilterableCard>(cards: readonly Card[], filter: SideFilter): Card[] {
  const needle = fold(filter.query)
  return cards.filter(
    (card) =>
      anyOf(filter.rarities, (rarity) => rarity === card.rarity) &&
      filter.chips.every((chip) => CHIP_MATCHES[chip](card)) &&
      anyOf(filter.genres, (genre) => genre === card.genre) &&
      anyOf(filter.goals, (goal) => card.goals.includes(goal)) &&
      fold(card.title).includes(needle),
  )
}
