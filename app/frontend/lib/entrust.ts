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

export type Layout = "wide" | "phone"

export type Selecting = "idle" | "loading" | "failed"

export type EntrustState = {
  copies: Readonly<Record<string, Copy>>
  loaded: readonly string[]
  capLeft: number
  ticked: Readonly<Record<string, number>>
  active: string | null
  selecting: Selecting
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

function byRef(copies: readonly Copy[]): Record<string, Copy> {
  return Object.fromEntries(copies.map((copy) => [copy.ref, copy]))
}

// The cells loaded in the grid are `loaded`; `copies` also keeps every copy ticked off the loaded pages.
export function start(
  copies: readonly Copy[],
  capLeft: number,
  ticked: Readonly<Record<string, number>>,
  loaded: readonly string[] = copies.map((copy) => copy.ref),
): EntrustState {
  const known = byRef(copies)
  const kept: Record<string, number> = {}
  for (const [ref, count] of Object.entries(ticked)) {
    const max = known[ref]?.free
    if (max !== undefined && max >= 1 && count >= 1) kept[ref] = clampValue(count, max)
  }
  return withActive({
    copies: known,
    loaded,
    capLeft,
    ticked: kept,
    active: null,
    selecting: "idle",
    layout: "wide",
    pendingLayout: null,
    sheetOpen: false,
  })
}

function withActive(state: EntrustState): EntrustState {
  if (state.active !== null && state.loaded.includes(state.active)) return state
  const active = state.loaded[0] ?? null
  return active === state.active ? state : { ...state, active }
}

// The grid's cells as they stand after a page loaded or the filters reloaded it; what they say of a copy is the latest.
export function know(state: EntrustState, copies: readonly Copy[], loaded: readonly string[]): EntrustState {
  const same = loaded.length === state.loaded.length && loaded.every((ref, index) => state.loaded[index] === ref)
  if (copies.length === 0 && same) return state
  return withActive({ ...state, copies: { ...state.copies, ...byRef(copies) }, loaded: same ? state.loaded : loaded })
}

// Ticks every copy given at one copy each; a tick already set keeps its count.
export function selectAll(state: EntrustState, copies: readonly Copy[]): EntrustState {
  const ticked: Record<string, number> = { ...state.ticked }
  for (const copy of copies) if (copy.free >= 1 && !(copy.ref in ticked)) ticked[copy.ref] = 1
  return { ...state, copies: { ...state.copies, ...byRef(copies) }, ticked, selecting: "idle" }
}

export function selecting(state: EntrustState, phase: Selecting): EntrustState {
  return state.selecting === phase ? state : { ...state, selecting: phase }
}

export function toggle(state: EntrustState, ref: string): EntrustState {
  const copy = state.copies[ref]
  if (!copy) return state
  if (ref in state.ticked) {
    const { [ref]: _dropped, ...rest } = state.ticked
    return { ...state, ticked: rest, active: ref }
  }
  if (copy.free < 1) return state
  return { ...state, ticked: { ...state.ticked, [ref]: 1 }, active: ref }
}

export function setCopies(state: EntrustState, ref: string, copies: number): EntrustState {
  const copy = state.copies[ref]
  if (!copy || !(ref in state.ticked)) return state
  const next = clampValue(copies, copy.free)
  return next === state.ticked[ref] ? state : { ...state, ticked: { ...state.ticked, [ref]: next } }
}

export function bump(state: EntrustState, ref: string, step: number): EntrustState {
  const current = state.ticked[ref]
  return current === undefined ? state : setCopies(state, ref, current + step)
}

export function filterCount({ rarities, doubles }: Pick<EntrustFilter, "rarities" | "doubles">): number {
  return rarities.length + (doubles ? 1 : 0)
}

export function filtering(filter: EntrustFilter): boolean {
  return filter.query.trim() !== "" || filterCount(filter) > 0
}

export function moveActive(state: EntrustState, key: string, columns: number): EntrustState {
  const index = state.active === null ? -1 : state.loaded.indexOf(state.active)
  if (index === -1) return state
  const next = nextIndex(key, index, state.loaded.length, columns)
  const ref = next === null ? undefined : state.loaded[next]
  return ref === undefined || ref === state.active ? state : { ...state, active: ref }
}

export function setActive(state: EntrustState, ref: string): EntrustState {
  return state.active === ref || !state.copies[ref] ? state : { ...state, active: ref }
}

const compareText = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0)

// The list's order: most valuable first, then by season, title and ref.
export function listOrder(a: Copy, b: Copy): number {
  return b.value - a.value || a.season - b.season || compareText(a.title, b.title) || compareText(a.ref, b.ref)
}

export function tickedCopies(state: EntrustState): Copy[] {
  return Object.keys(state.ticked)
    .flatMap((ref) => state.copies[ref] ?? [])
    .sort(listOrder)
}

// The operation's rule: copies counted in list order, a line that does not fit stays and a cheaper one after it may pass.
export function preview(state: EntrustState): Preview {
  let left = state.capLeft
  const lines: PreviewLine[] = []
  for (const copy of tickedCopies(state)) {
    const copies = state.ticked[copy.ref] ?? 0
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
