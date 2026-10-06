// A horizontal swipe's step (EXPERIENCE.md, Interaction primitives: "in the
// card detail, swipe or the ◀ ▶ buttons move between cards"), read by the
// sub-view controller. A finger moving left goes to the next card, right
// to the previous one; only when the move is mostly horizontal and long
// enough, so a vertical drag stays a scroll.

/** How far, in px, a finger travels sideways before it counts as a swipe. */
export const SWIPE_THRESHOLD = 70

/**
 * The step for a finger that moved `dx`, `dy` px between press and
 * release: 1 (next) for a swipe to the left, -1 (previous) to the right,
 * 0 for anything else (too short, or not mostly horizontal).
 */
export function swipeStep(dx: number, dy: number, threshold = SWIPE_THRESHOLD): -1 | 0 | 1 {
  if (Math.abs(dx) < threshold || Math.abs(dx) <= Math.abs(dy)) return 0
  return dx < 0 ? 1 : -1
}
