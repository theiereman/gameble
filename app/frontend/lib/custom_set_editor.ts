import { nextIndex } from "./grid_keys"

export const GAME_FILTERS = ["all", "owned", "missing", "picked"] as const

export type GameFilter = (typeof GAME_FILTERS)[number]

export type Refusal = "limit" | null

export type EditorState = {
  readonly openedWith: { readonly name: string; readonly picks: readonly string[] }
  readonly picks: readonly string[]
  readonly filter: GameFilter
  readonly query: string
  readonly active: string | null
  readonly refusal: Refusal
}

export type Toggled = { state: EditorState; refused: boolean }

export function initialState(name: string, picks: readonly string[]): EditorState {
  const unique = [...new Set(picks)]
  return { openedWith: { name, picks: unique }, picks: unique, filter: "all", query: "", active: null, refusal: null }
}

export function reset(state: EditorState): EditorState {
  return initialState(state.openedWith.name, state.openedWith.picks)
}

export function hasChanges(state: EditorState, name: string): boolean {
  const { openedWith } = state
  if (name !== openedWith.name || state.picks.length !== openedWith.picks.length) return true
  return state.picks.some((pick) => !openedWith.picks.includes(pick))
}

export function isFilter(value: string): value is GameFilter {
  return (GAME_FILTERS as readonly string[]).includes(value)
}

export function toggle(state: EditorState, key: string, max: number): Toggled {
  if (state.picks.includes(key))
    return {
      state: { ...state, picks: state.picks.filter((pick) => pick !== key), active: key, refusal: null },
      refused: false,
    }
  if (state.picks.length >= max) return { state: { ...state, active: key, refusal: "limit" }, refused: true }
  return { state: { ...state, picks: [...state.picks, key], active: key, refusal: null }, refused: false }
}

export function setFilter(state: EditorState, filter: GameFilter): EditorState {
  return { ...state, filter }
}

export function setQuery(state: EditorState, query: string): EditorState {
  return { ...state, query }
}

export function setActive(state: EditorState, active: string | null): EditorState {
  return { ...state, active }
}

export function clearRefusal(state: EditorState): EditorState {
  return { ...state, refusal: null }
}

export function isPicked(state: EditorState, key: string): boolean {
  return state.picks.includes(key)
}

export function activeKey(state: EditorState, keys: readonly string[]): string | null {
  if (state.active !== null && keys.includes(state.active)) return state.active
  return keys[0] ?? null
}

export function move(state: EditorState, keys: readonly string[], key: string, columns: number): string | null {
  const current = activeKey(state, keys)
  if (current === null) return null
  const index = nextIndex(key, keys.indexOf(current), keys.length, columns)
  return index === null ? null : (keys[index] ?? null)
}

export function gamesUrl(base: string, state: EditorState): string {
  const params = new URLSearchParams()
  const query = state.query.trim()
  if (query !== "") params.set("q", query)
  if (state.filter !== "all") params.set("state", state.filter)
  if (state.filter === "picked") for (const pick of state.picks) params.append("games[]", pick)
  const search = params.toString()
  return search === "" ? base : `${base}?${search}`
}

export function gameLabel(base: string, picked: boolean, inSet: string): string {
  return picked ? `${base}${inSet}` : base
}
