// A horizontal swipe's step: left is next, right is previous, only when mostly horizontal and long enough.

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
