import { sameLines, type DraftField, type DraftSides } from "./trade_board_draft"
import { PICKER_PAGE, nextPage, shownFor } from "./trade_board_faces"
import {
  FRESH_PICKER_FILTERS,
  activeChips,
  clearedFilters,
  filterCards,
  filtering,
  moreChips,
  toggledFold,
  toggledMoreFold,
  withFilter,
  type FilterableCard,
  type PickerFilters,
  type SideFilter,
} from "./trade_board_filter"

export * from "./trade_board_filter"

export type Line = { key: string; quantity: number }

export type Side = "friend" | "own"

export type SideCount = { cards: number; copies: number }

export const MAX_CARDS = 4

export type Maxima = ReadonlyMap<string, number>

export function initialLines(lines: readonly Line[], maxima: Maxima): Line[] {
  const seen = new Set<string>()
  const result: Line[] = []
  for (const line of lines) {
    const max = maxima.get(line.key) ?? 0
    if (max < 1 || seen.has(line.key) || result.length >= MAX_CARDS) continue
    seen.add(line.key)
    result.push({ key: line.key, quantity: clamp(line.quantity, 1, max) })
  }
  return result
}

export type Toggle = { lines: Line[]; refused: boolean }

export function toggle(lines: readonly Line[], key: string, max: number): Toggle {
  if (lines.some((line) => line.key === key)) return { lines: remove(lines, key), refused: false }
  if (max < 1) return { lines: [...lines], refused: false }
  if (lines.length >= MAX_CARDS) return { lines: [...lines], refused: true }
  return { lines: [...lines, { key, quantity: 1 }], refused: false }
}

export function setQuantity(lines: readonly Line[], key: string, quantity: number, max: number): Line[] {
  return lines.map((line) => (line.key === key ? { key, quantity: clamp(quantity, 1, Math.max(1, max)) } : line))
}

export function remove(lines: readonly Line[], key: string): Line[] {
  return lines.filter((line) => line.key !== key)
}

export function sideCount(lines: readonly Line[]): SideCount {
  return { cards: lines.length, copies: lines.reduce((sum, line) => sum + line.quantity, 0) }
}

export function showsOpenHelp(side: Side, lines: readonly Line[]): boolean {
  return side === "own" && lines.length === 0
}

export function gridMove(index: number, key: string, count: number, columns: number): number | null {
  if (count < 1) return null
  const width = Math.max(1, columns)
  const target = (() => {
    switch (key) {
      case "ArrowLeft":
        return index - 1
      case "ArrowRight":
        return index + 1
      case "ArrowUp":
        return index - width
      case "ArrowDown":
        return index + width
      case "Home":
        return 0
      case "End":
        return count - 1
      default:
        return null
    }
  })()
  if (target === null) return null
  return target < 0 || target >= count ? index : target
}

export function columnsOf(tops: readonly number[]): number {
  if (tops.length === 0) return 1
  const first = tops[0]
  const columns = tops.findIndex((top) => Math.abs(top - first) > 1)
  return columns === -1 ? tops.length : columns
}

export type TradeCard = FilterableCard & { key: string; owned: number; reserved: number }

export const SIDES: readonly Side[] = ["friend", "own"]

export const FIELDS: Readonly<Record<Side, DraftField>> = { friend: "take", own: "give" }

export type BySide<Value> = Readonly<Record<Side, Value>>

export type Picker = Readonly<{
  side: Side
  selection: readonly Line[]
  refused: boolean
  activeKey: string | null
  shown: number
}>

export type BoardState = Readonly<{
  catalogue: BySide<readonly TradeCard[]>
  received: BySide<readonly Line[]>
  lines: BySide<readonly Line[]>
  editing: boolean
  picker: Picker | null
  filters: BySide<PickerFilters>
}>

export type BoardStart = {
  catalogue: BySide<readonly TradeCard[]>
  received: BySide<readonly Line[]>
  editing: boolean
  draft: DraftSides | null
  filters?: BySide<PickerFilters>
}

export type EmptyReason = "none" | "reserved" | "unmatched"

export type PickerView = Readonly<{
  side: Side
  shownKeys: readonly string[]
  activeKey: string | null
  hasMore: boolean
  matches: number
  hasCards: boolean
  empty: EmptyReason | null
  selection: readonly Line[]
  count: SideCount
  refused: boolean
  filter: SideFilter
  folded: boolean
  moreFolded: boolean
  chipsOn: number
  moreOn: number
  filtering: boolean
}>

export const bySide = <Value>(value: (side: Side) => Value): BySide<Value> => ({
  friend: value("friend"),
  own: value("own"),
})

const maximaOf = (cards: readonly TradeCard[]): Maxima => new Map(cards.map((card) => [card.key, card.max]))

export function start({ catalogue, received, editing, draft, filters }: BoardStart): BoardState {
  const maxima = bySide((side) => maximaOf(catalogue[side]))
  const settled = bySide((side) => initialLines(received[side], maxima[side]))
  const lines = draft ? bySide((side) => initialLines(draft[FIELDS[side]] ?? [], maxima[side])) : settled
  return {
    catalogue,
    received: settled,
    lines,
    editing,
    picker: null,
    filters: filters ?? { friend: FRESH_PICKER_FILTERS, own: FRESH_PICKER_FILTERS },
  }
}

export function cardOf(state: BoardState, side: Side, key: string): TradeCard | undefined {
  return state.catalogue[side].find((card) => card.key === key)
}

export function edit(state: BoardState): BoardState {
  return { ...state, editing: true, picker: null }
}

export function restore(state: BoardState): BoardState {
  return { ...state, editing: false, lines: state.received, picker: null }
}

export function adopted(state: BoardState): BoardState {
  return { ...state, received: { friend: [], own: [] } }
}

function withLines(state: BoardState, side: Side, lines: readonly Line[]): BoardState {
  return { ...state, lines: { ...state.lines, [side]: lines } }
}

export function removeLine(state: BoardState, side: Side, key: string): BoardState {
  if (!state.lines[side].some((line) => line.key === key)) return state
  return withLines(state, side, remove(state.lines[side], key))
}

export function setLineQuantity(state: BoardState, side: Side, key: string, quantity: number): BoardState {
  const card = cardOf(state, side, key)
  if (!card) return state
  const next = setQuantity(state.lines[side], key, quantity, card.max)
  return sameLines(next, state.lines[side]) ? state : withLines(state, side, next)
}

export function visibleCards(state: BoardState, side: Side): TradeCard[] {
  return filterCards(state.catalogue[side], state.filters[side].filter)
}

function settled(state: BoardState, picker: Picker): BoardState {
  const shown = visibleCards(state, picker.side).slice(0, picker.shown)
  const active = shown.some((card) => card.key === picker.activeKey) ? picker.activeKey : (shown[0]?.key ?? null)
  return { ...state, picker: active === picker.activeKey ? picker : { ...picker, activeKey: active } }
}

export function openPicker(state: BoardState, side: Side): BoardState {
  const lines = state.lines[side]
  return settled(state, {
    side,
    selection: lines,
    refused: false,
    activeKey: lines[0]?.key ?? null,
    shown: PICKER_PAGE,
  })
}

export function togglePick(state: BoardState, key: string): BoardState {
  const { picker } = state
  const card = picker && cardOf(state, picker.side, key)
  if (!picker || !card) return state
  const next = toggle(picker.selection, key, card.max)
  return { ...state, picker: { ...picker, activeKey: key, selection: next.lines, refused: next.refused } }
}

export function setPickQuantity(state: BoardState, key: string, quantity: number): BoardState {
  const { picker } = state
  const card = picker && cardOf(state, picker.side, key)
  if (!picker || !card) return state
  const selection = setQuantity(picker.selection, key, quantity, card.max)
  return sameLines(selection, picker.selection) ? state : { ...state, picker: { ...picker, selection } }
}

function withFilters(state: BoardState, change: (filters: PickerFilters) => PickerFilters): BoardState {
  const { picker } = state
  if (!picker) return state
  const filters = { ...state.filters, [picker.side]: change(state.filters[picker.side]) }
  return settled({ ...state, filters }, { ...picker, shown: PICKER_PAGE })
}

export function setFilter(state: BoardState, filter: SideFilter): BoardState {
  return withFilters(state, (filters) => withFilter(filters, filter))
}

export function clearFilters(state: BoardState): BoardState {
  return withFilters(state, clearedFilters)
}

function withFolds(state: BoardState, change: (filters: PickerFilters) => PickerFilters): BoardState {
  const { picker } = state
  if (!picker) return state
  return { ...state, filters: { ...state.filters, [picker.side]: change(state.filters[picker.side]) } }
}

export function toggleFold(state: BoardState): BoardState {
  return withFolds(state, toggledFold)
}

export function toggleMoreFold(state: BoardState): BoardState {
  return withFolds(state, toggledMoreFold)
}

export function showMore(state: BoardState): BoardState {
  const { picker } = state
  if (!picker || picker.shown >= visibleCards(state, picker.side).length) return state
  return { ...state, picker: { ...picker, shown: nextPage(picker.shown) } }
}

export function moveActive(state: BoardState, key: string, columns: number): BoardState {
  const { picker } = state
  if (!picker) return state
  const visible = visibleCards(state, picker.side)
  const active = visible.slice(0, picker.shown).findIndex((card) => card.key === picker.activeKey)
  const next = gridMove(Math.max(0, active), key, visible.length, columns)
  if (next === null) return state
  return {
    ...state,
    picker: { ...picker, activeKey: visible[next]?.key ?? null, shown: Math.max(picker.shown, shownFor(next)) },
  }
}

export function place(state: BoardState): BoardState {
  const { picker } = state
  if (!picker) return state
  return { ...withLines(state, picker.side, picker.selection), picker: null }
}

export function closePicker(state: BoardState): BoardState {
  return state.picker ? { ...state, picker: null } : state
}

export function changed(state: BoardState): boolean {
  return SIDES.some((side) => !sameLines(state.lines[side], state.received[side]))
}

export function sendable(state: BoardState): boolean {
  return state.lines.friend.length > 0
}

export function draftSides(state: BoardState): DraftSides {
  return { [FIELDS.friend]: state.lines.friend, [FIELDS.own]: state.lines.own }
}

function emptyReason(cards: readonly TradeCard[], matches: number): EmptyReason | null {
  if (cards.length === 0) return "none"
  if (cards.every((card) => card.max < 1)) return "reserved"
  return matches === 0 ? "unmatched" : null
}

export function pickerView(state: BoardState): PickerView | null {
  const { picker } = state
  if (!picker) return null
  const cards = state.catalogue[picker.side]
  const { filter, folded, moreFolded } = state.filters[picker.side]
  const visible = visibleCards(state, picker.side)
  return {
    side: picker.side,
    shownKeys: visible.slice(0, picker.shown).map((card) => card.key),
    activeKey: picker.activeKey,
    hasMore: picker.shown < visible.length,
    matches: visible.length,
    hasCards: cards.length > 0,
    empty: emptyReason(cards, visible.length),
    selection: picker.selection,
    count: sideCount(picker.selection),
    refused: picker.refused,
    filter,
    folded,
    moreFolded,
    chipsOn: activeChips(filter),
    moreOn: moreChips(filter),
    filtering: filtering(filter),
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, Math.trunc(value)))
}
