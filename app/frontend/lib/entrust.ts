import type { Rarity } from "./card_types"
import { clampValue } from "./stepper"
import { nextIndex } from "./grid_keys"

export type Copy = {
  ref: string
  title: string
  rarity: Rarity
  season: number
  free: number
  owned: number
  value: number
}

export type EntrustFilter = {
  query: string
  rarities: readonly Rarity[]
  doubles: boolean
}

export const DEFAULT_FILTER: EntrustFilter = { query: "", rarities: [], doubles: true }
export const CLEARED_FILTER: EntrustFilter = { query: "", rarities: [], doubles: false }

export type Layout = "wide" | "phone"

export type EntrustState = {
  copies: readonly Copy[]
  capLeft: number
  ticked: Readonly<Record<string, number>>
  filter: EntrustFilter
  active: string | null
  layout: Layout
  pendingLayout: Layout | null
  sheetOpen: boolean
}

export type PreviewLine = {
  copy: Copy
  copies: number
  entrusted: number
  stayed: number
}

export type Preview = {
  lines: readonly PreviewLine[]
  received: number
  count: number
  stayedCount: number
  capUsed: number
  capLeft: number
  rareNames: readonly string[]
  rareCount: number
  full: boolean
  canValidate: boolean
  pending: boolean
}

const RARE_OR_BETTER: readonly Rarity[] = ["rare", "epic", "legendary"]

function fold(text: string): string {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().trim()
}

export function start(
  copies: readonly Copy[],
  capLeft: number,
  ticked: Readonly<Record<string, number>>,
  filter: EntrustFilter = DEFAULT_FILTER,
): EntrustState {
  const free = new Map(copies.map((copy) => [copy.ref, copy.free]))
  const kept: Record<string, number> = {}
  for (const [ref, count] of Object.entries(ticked)) {
    const max = free.get(ref)
    if (max !== undefined && max >= 1 && count >= 1) kept[ref] = clampValue(count, max)
  }
  return withActive({
    copies,
    capLeft,
    ticked: kept,
    filter,
    active: null,
    layout: "wide",
    pendingLayout: null,
    sheetOpen: false,
  })
}

function matches(copy: Copy, { query, rarities, doubles }: EntrustFilter): boolean {
  return (
    (rarities.length === 0 || rarities.includes(copy.rarity)) &&
    (!doubles || copy.owned >= 2) &&
    fold(copy.title).includes(fold(query))
  )
}

export function visible(state: EntrustState): Copy[] {
  return state.copies.filter((copy) => matches(copy, state.filter))
}

function withActive(state: EntrustState): EntrustState {
  const shown = visible(state)
  if (state.active !== null && shown.some((copy) => copy.ref === state.active)) return state
  return { ...state, active: shown[0]?.ref ?? null }
}

function find(state: EntrustState, ref: string): Copy | undefined {
  return state.copies.find((copy) => copy.ref === ref)
}

export function toggle(state: EntrustState, ref: string): EntrustState {
  const copy = find(state, ref)
  if (!copy) return state
  if (ref in state.ticked) {
    const { [ref]: _dropped, ...rest } = state.ticked
    return { ...state, ticked: rest, active: ref }
  }
  if (copy.free < 1) return state
  return { ...state, ticked: { ...state.ticked, [ref]: 1 }, active: ref }
}

export function setCopies(state: EntrustState, ref: string, copies: number): EntrustState {
  const copy = find(state, ref)
  if (!copy || !(ref in state.ticked)) return state
  const next = clampValue(copies, copy.free)
  return next === state.ticked[ref] ? state : { ...state, ticked: { ...state.ticked, [ref]: next } }
}

export function bump(state: EntrustState, ref: string, step: number): EntrustState {
  const current = state.ticked[ref]
  return current === undefined ? state : setCopies(state, ref, current + step)
}

export function setFilter(state: EntrustState, filter: EntrustFilter): EntrustState {
  return withActive({ ...state, filter })
}

export function clearFilters(state: EntrustState): EntrustState {
  return setFilter(state, CLEARED_FILTER)
}

export function filterCount({ rarities, doubles }: EntrustFilter): number {
  return rarities.length + (doubles ? 1 : 0)
}

export function filtering(filter: EntrustFilter): boolean {
  return filter.query.trim() !== "" || filterCount(filter) > 0
}

export function moveActive(state: EntrustState, key: string, columns: number): EntrustState {
  const shown = visible(state)
  const index = shown.findIndex((copy) => copy.ref === state.active)
  if (index === -1) return state
  const next = nextIndex(key, index, shown.length, columns)
  const ref = next === null ? undefined : shown[next]?.ref
  return ref === undefined || ref === state.active ? state : { ...state, active: ref }
}

export function setActive(state: EntrustState, ref: string): EntrustState {
  return state.active === ref || !find(state, ref) ? state : { ...state, active: ref }
}

// The operation's rule: copies counted in list order, a line that does not fit stays and a cheaper one after it may pass.
export function preview(state: EntrustState): Preview {
  let left = state.capLeft
  const lines: PreviewLine[] = []
  for (const copy of state.copies) {
    const copies = state.ticked[copy.ref]
    if (copies === undefined) continue
    const entrusted = Math.min(copies, Math.floor(left / copy.value))
    left -= entrusted * copy.value
    lines.push({ copy, copies, entrusted, stayed: copies - entrusted })
  }
  const received = state.capLeft - left
  const count = lines.reduce((sum, line) => sum + line.entrusted, 0)
  const rare = lines.filter((line) => line.entrusted > 0 && RARE_OR_BETTER.includes(line.copy.rarity))
  const full = state.capLeft <= 0
  return {
    lines,
    received,
    count,
    stayedCount: lines.reduce((sum, line) => sum + line.stayed, 0),
    capUsed: received,
    capLeft: left,
    rareNames: rare.map((line) => line.copy.title),
    rareCount: rare.reduce((sum, line) => sum + line.entrusted, 0),
    full,
    canValidate: lines.length > 0 && !full,
    pending: lines.length > 0,
  }
}
