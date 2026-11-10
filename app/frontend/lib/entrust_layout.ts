import type { EntrustState, Layout } from "./entrust"

export const PHONE_QUERY = "(max-width: 719px)"

export function layoutFor(phoneMatches: boolean): Layout {
  return phoneMatches ? "phone" : "wide"
}

export function idle(state: EntrustState): boolean {
  return !state.sheetOpen
}

function settle(state: EntrustState): EntrustState {
  if (state.pendingLayout === null) return state
  return { ...state, layout: state.pendingLayout, pendingLayout: null }
}

export function layoutAsked(state: EntrustState, layout: Layout): EntrustState {
  const pendingLayout = layout === state.layout ? null : layout
  if (pendingLayout === state.pendingLayout) return idle(state) ? settle(state) : state
  const asked = { ...state, pendingLayout }
  return idle(asked) ? settle(asked) : asked
}

export function sheetShown(state: EntrustState, shown: boolean): EntrustState {
  if (state.sheetOpen === shown) return state
  const next = { ...state, sheetOpen: shown }
  return shown ? next : settle(next)
}
