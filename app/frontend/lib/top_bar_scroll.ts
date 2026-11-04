export const HIDE_AFTER = 80
export const SCROLL_DELTA = 8

export type ScrollState = { shown: boolean; anchor: number }

export type ScrollInput = { offset: number; holdOpen: boolean }

export const initialScrollState: ScrollState = { shown: true, anchor: 0 }

export function nextScrollState(state: ScrollState, { offset, holdOpen }: ScrollInput): ScrollState {
  if (holdOpen || offset <= HIDE_AFTER) return { shown: true, anchor: offset }

  const travelled = offset - state.anchor
  if (Math.abs(travelled) < SCROLL_DELTA) return state
  return { shown: travelled < 0, anchor: offset }
}
