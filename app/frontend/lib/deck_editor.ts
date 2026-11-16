import { ALL_TRUMPS, BY_TITLE, sortRefs, visibleRefs, type Percentiles } from "./deck_collection_order"
import { coverageOf, placementsOf, type CoverageCell } from "./deck_editor_answers"
import { nextIndex } from "./grid_keys"
import { t, type Template, type Vars } from "./i18n"

export type { CoverageCell } from "./deck_editor_answers"

export const SLOT_COUNT = 12

export type Availability = "available" | "unranked" | "reserved"

export type Entry = {
  ref: string
  game: string
  title: string
  image: string
  availability: Availability
  percentiles: Percentiles
  trump: string
  movesText: string
  movesSentence: string
}

export type Change =
  | { kind: "create"; name: string | null }
  | { kind: "rename"; name: string }
  | { kind: "add"; ref: string; slot: number }
  | { kind: "remove"; ref: string; slot: number }
  | { kind: "fill" }

export type Notice =
  | { kind: "added" | "removed"; ref: string; count: number }
  | { kind: "full" | "same_game" | "save_failed" }
  | { kind: "unavailable"; reason: Exclude<Availability, "available"> }
  | { kind: "refused"; message: string }
  | { kind: "filled"; count: number; total: number }
  | { kind: "sorted"; call: string }

export type DeckState = {
  token: string | null
  url: string | null
  name: string
  savedName: string
  slots: readonly (string | null)[]
  entries: Readonly<Record<string, Entry>>
  order: readonly string[]
  sort: string
  trump: string
  coverage: readonly CoverageCell[] | null
  pending: readonly Change[]
  active: string | null
  notice: Notice | null
  noticeCount: number
  nameRefusal: string | null
}

export type Saved = {
  token?: string
  url?: string
  name?: string
  slot?: number
  count?: number
  slots?: unknown
  coverage?: unknown
}

export type DeckStrings = {
  add: string
  added: string
  countHidden: string
  deleteTitle: string
  full: string
  inDeck: string
  inDeckSuffix: string
  removeSlot: string
  removed: string
  sameGame: string
  saveFailed: string
  notYetRanked: string
  noFreeCopy: string
  coverageCovered: string
  filled: Template
  sorted: string
  calls: Readonly<Record<string, string>>
}

export type SlotView = { ref: string; title: string; image: string; label: string; moves: string } | null

export type EntryView = { inDeck: boolean; tabbable: boolean; hidden: boolean }

export type CollectionView = { sort: string; trump: string; entries: ReadonlyMap<string, EntryView> }

export type Request = { url: string; method: "POST" | "PATCH" | "DELETE"; body: Record<string, string | null> }

const NAME_CODES = ["deck_name_required", "deck_name_too_long", "deck_name_taken"]

type Start = {
  token: string | null
  url: string | null
  name: string
  slots: readonly (string | null)[]
  entries: readonly Entry[]
}

export function start({ token, url, name, slots, entries }: Start): DeckState {
  const filled = Array.from({ length: SLOT_COUNT }, (_, index) => slots[index] || null)
  return {
    token: token || null,
    url: url || null,
    name,
    savedName: name,
    slots: filled,
    entries: Object.fromEntries(entries.map((entry) => [entry.ref, entry])),
    order: entries.map((entry) => entry.ref),
    sort: BY_TITLE,
    trump: ALL_TRUMPS,
    coverage: null,
    pending: [],
    active: entries[0]?.ref ?? null,
    notice: null,
    noticeCount: 0,
    nameRefusal: null,
  }
}

export const countOf = (state: DeckState): number => state.slots.filter((ref) => ref !== null).length

const sortedOrder = (state: DeckState): string[] => sortRefs(state.entries, state.order, state.sort)

const visibleOrder = (state: DeckState): string[] => visibleRefs(state.entries, sortedOrder(state), state.trump)

function noticed(state: DeckState, notice: Notice): DeckState {
  return { ...state, notice, noticeCount: state.noticeCount + 1 }
}

function queued(state: DeckState, change: Change): readonly Change[] {
  if (state.token !== null || state.pending.some((pending) => pending.kind === "create"))
    return [...state.pending, change]
  if (change.kind === "rename") return [...state.pending, { kind: "create", name: change.name }]
  return [...state.pending, { kind: "create", name: null }, change]
}

function withSlot(slots: readonly (string | null)[], slot: number, ref: string | null): (string | null)[] {
  return slots.map((current, index) => (index === slot - 1 ? ref : current))
}

function take(state: DeckState, slot: number): DeckState {
  const ref = state.slots[slot - 1]
  if (!ref) return state
  const slots = withSlot(state.slots, slot, null)
  const next = { ...state, slots, pending: queued(state, { kind: "remove", ref, slot }) }
  return noticed(next, { kind: "removed", ref, count: countOf(next) })
}

export function choose(state: DeckState, ref: string): DeckState {
  const entry = state.entries[ref]
  if (!entry) return state
  const active = { ...state, active: ref }
  const slot = state.slots.indexOf(ref)
  if (slot !== -1) return take(active, slot + 1)
  if (entry.availability !== "available") return noticed(active, { kind: "unavailable", reason: entry.availability })
  if (state.slots.some((held) => held !== null && state.entries[held]?.game === entry.game))
    return noticed(active, { kind: "same_game" })
  const free = state.slots.indexOf(null)
  if (free === -1) return noticed(active, { kind: "full" })
  const next = { ...active, slots: withSlot(state.slots, free + 1, ref) }
  const added = { ...next, pending: queued(state, { kind: "add", ref, slot: free + 1 }) }
  return noticed(added, { kind: "added", ref, count: countOf(added) })
}

export function removeSlot(state: DeckState, slot: number): DeckState {
  return take(state, slot)
}

export function rename(state: DeckState, typed: string): DeckState {
  const name = typed.trim()
  if (name === state.name) return state.nameRefusal ? { ...state, nameRefusal: null } : state
  return { ...state, name, nameRefusal: null, pending: queued(state, { kind: "rename", name }) }
}

export function sortBy(state: DeckState, sort: string): DeckState {
  return sort === state.sort ? state : { ...state, sort }
}

export function chooseGap(state: DeckState, call: string): DeckState {
  return noticed({ ...state, sort: call }, { kind: "sorted", call })
}

export function filterBy(state: DeckState, trump: string): DeckState {
  if (trump === state.trump) return state
  const next = { ...state, trump }
  const visible = visibleOrder(next)
  return state.active !== null && visible.includes(state.active) ? next : { ...next, active: visible[0] ?? null }
}

export function fill(state: DeckState): DeckState {
  return { ...state, pending: queued(state, { kind: "fill" }) }
}

export function nextToSend(state: DeckState): Change | null {
  return state.pending[0] ?? null
}

export function requestFor(state: DeckState, change: Change, createUrl: string): Request | null {
  if (change.kind === "create") return { url: createUrl, method: "POST", body: { name: change.name } }
  if (state.url === null) return null
  if (change.kind === "rename") return { url: state.url, method: "PATCH", body: { name: change.name } }
  if (change.kind === "fill") return { url: `${state.url}/fill`, method: "POST", body: {} }
  return { url: `${state.url}/cards`, method: change.kind === "add" ? "POST" : "DELETE", body: { ref: change.ref } }
}

const renamedLater = (pending: readonly Change[]): boolean =>
  pending.some((change) => change.kind === "rename" || change.kind === "create")

export function saved(state: DeckState, body: Saved): DeckState {
  const [head, ...rest] = state.pending
  if (!head) return state
  const next = { ...state, pending: rest, coverage: coverageOf(body.coverage) ?? state.coverage }
  if (head.kind === "add") return { ...next, slots: placedAt(state.slots, head.ref, body.slot) }
  if (head.kind === "remove") return next
  if (head.kind === "fill") return filledBy(next, body)
  const savedName = body.name ?? state.savedName
  const named = { ...next, savedName, name: renamedLater(rest) ? state.name : savedName }
  return head.kind === "create" ? { ...named, token: body.token ?? null, url: body.url ?? null } : named
}

function placedAt(slots: readonly (string | null)[], ref: string, slot: unknown): readonly (string | null)[] {
  const from = slots.indexOf(ref)
  if (typeof slot !== "number" || from === -1 || slot - 1 === from || slot < 1 || slot > SLOT_COUNT) return slots
  const swapped = [...slots]
  swapped[from] = slots[slot - 1] ?? null
  swapped[slot - 1] = ref
  return swapped
}

function filledBy(state: DeckState, body: Saved): DeckState {
  const placements = placementsOf(body.slots)
  const slots = placements.reduce((current, { slot, ref }) => placedByFill(current, slot, ref), state.slots)
  const next = { ...state, slots }
  const total = typeof body.count === "number" ? body.count : countOf(next)
  return noticed(next, { kind: "filled", count: placements.length, total })
}

function placedByFill(slots: readonly (string | null)[], slot: number, ref: string): readonly (string | null)[] {
  if (slot < 1 || slot > SLOT_COUNT) return slots
  if (slots.includes(ref)) return placedAt(slots, ref, slot)
  const occupant = slots[slot - 1] ?? null
  const next = withSlot(slots, slot, ref)
  const free = next.indexOf(null)
  return occupant === null || free === -1 ? next : withSlot(next, free + 1, occupant)
}

export function failed(state: DeckState): DeckState {
  return noticed(state, { kind: "save_failed" })
}

function reverted(slots: readonly (string | null)[], change: Change): readonly (string | null)[] {
  if (change.kind === "add") return slots.map((ref) => (ref === change.ref ? null : ref))
  if (change.kind === "remove" && slots[change.slot - 1] === null && !slots.includes(change.ref))
    return withSlot(slots, change.slot, change.ref)
  return slots
}

function refusedName(state: DeckState, rest: readonly Change[], message: string): DeckState {
  return { ...state, pending: rest, name: renamedLater(rest) ? state.name : state.savedName, nameRefusal: message }
}

export function refused(state: DeckState, code: string, message: string): DeckState {
  const [head, ...rest] = state.pending
  if (!head) return state
  const byName = NAME_CODES.includes(code)
  if (head.kind === "create") {
    if (byName) return refusedName(state, rest.length > 0 ? [{ kind: "create", name: null }, ...rest] : [], message)
    const slots = [...state.pending].reverse().reduce(reverted, state.slots)
    return noticed({ ...state, slots, pending: [], name: state.savedName }, { kind: "refused", message })
  }
  if (head.kind === "rename") {
    if (byName) return refusedName(state, rest, message)
    return noticed(
      { ...state, pending: rest, name: renamedLater(rest) ? state.name : state.savedName },
      { kind: "refused", message },
    )
  }
  return noticed({ ...state, pending: rest, slots: reverted(state.slots, head) }, { kind: "refused", message })
}

export function move(state: DeckState, key: string, columns: number): DeckState {
  const order = visibleOrder(state)
  const index = state.active === null ? -1 : order.indexOf(state.active)
  if (index === -1) return state
  const next = nextIndex(key, index, order.length, columns)
  if (next === null || next === index) return state
  return { ...state, active: order[next] ?? state.active }
}

export function activateFirst(state: DeckState): DeckState {
  const first = visibleOrder(state)[0] ?? null
  return first === state.active ? state : { ...state, active: first }
}

export function focusAfterRemoval(state: DeckState, slot: number): number | null {
  const next = state.slots.findIndex((ref, index) => index >= slot && ref !== null)
  return next === -1 ? null : next + 1
}

export function slotsView(state: DeckState, strings: DeckStrings): SlotView[] {
  return state.slots.map((ref) => {
    const entry = ref === null ? undefined : state.entries[ref]
    if (!entry) return null
    return {
      ref: entry.ref,
      title: entry.title,
      image: entry.image,
      label: [t(strings.removeSlot, { card: entry.title }), entry.movesSentence].filter(Boolean).join(". "),
      moves: entry.movesText,
    }
  })
}

export function collectionView(state: DeckState): CollectionView {
  const inDeck = new Set(state.slots.filter((ref): ref is string => ref !== null))
  const visible = new Set(visibleOrder(state))
  const entries = new Map(
    sortedOrder(state).map((ref) => [
      ref,
      { inDeck: inDeck.has(ref), tabbable: ref === state.active, hidden: !visible.has(ref) },
    ]),
  )
  return { sort: state.sort, trump: state.trump, entries }
}

export function noticeText(state: DeckState, strings: DeckStrings): string {
  const notice = state.notice
  if (!notice) return ""
  const template: Template = {
    added: strings.added,
    removed: strings.removed,
    full: strings.full,
    same_game: strings.sameGame,
    save_failed: strings.saveFailed,
    unavailable: "reason" in notice && notice.reason === "unranked" ? strings.notYetRanked : strings.noFreeCopy,
    refused: "message" in notice ? notice.message : "",
    filled: strings.filled,
    sorted: strings.sorted,
  }[notice.kind]
  const card = "ref" in notice ? (state.entries[notice.ref]?.title ?? "") : ""
  const call = "call" in notice ? (strings.calls[notice.call] ?? notice.call) : ""
  const vars: Vars = { card, call }
  if ("count" in notice) vars.count = notice.count
  if ("total" in notice) vars.total = notice.total
  return t(template, vars)
}
