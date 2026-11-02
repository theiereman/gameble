export const HIDE_AFTER = 80
export const SCROLL_DELTA = 8

export type ScrollState = { shown: boolean; anchor: number }

export type ScrollInput = { offset: number; holdOpen: boolean }

export const initialScrollState: ScrollState = { shown: true, anchor: 0 }

// Hides after a downward scroll past HIDE_AFTER, shows after an upward one;
// movement under SCROLL_DELTA from the last turning point is ignored.
export function nextScrollState(state: ScrollState, { offset, holdOpen }: ScrollInput): ScrollState {
  if (holdOpen || offset <= HIDE_AFTER) return { shown: true, anchor: offset }

  const travelled = offset - state.anchor
  if (Math.abs(travelled) < SCROLL_DELTA) return state
  return { shown: travelled < 0, anchor: offset }
}
