// The top bar wordmark's hover sweep: while `data-sweeping` is on its brand,
// the stylesheet steps the wordmark's strip of shine frames
// (images/pixel/wordmark-sweep.svg, styles/shell.css) once, then the strip
// falls back to its rest frame. A sweep runs to its end once started; under
// reduced motion none starts.
import { motionReduced } from "./motion"

/** The CSS animation the sweep plays. */
export const SWEEP_ANIMATION = "wordmark-sweep"
/** The sweep's frames after the rest frame. */
export const SWEEP_STEPS = 22
/** How long each frame shows. */
export const STEP_MS = 40
/** The wordmark's height in art pixels: one frame of the strip. */
export const FRAME_ROWS = 9

export const SWEEPING = "data-sweeping"

export type SweepTarget = Pick<Element, "hasAttribute" | "setAttribute" | "removeAttribute">

/** Starts a sweep unless motion is reduced or one is running; whether one started. */
export function startSweep(element: SweepTarget): boolean {
  if (motionReduced()) {
    clearSweep(element)
    return false
  }
  if (element.hasAttribute(SWEEPING)) return false
  element.setAttribute(SWEEPING, "")
  return true
}

/** Ends the sweep when its animation ends or is cancelled; any other animation is not its end. */
export function endSweep(element: SweepTarget, animationName: string): void {
  if (animationName === SWEEP_ANIMATION) clearSweep(element)
}

/** Puts the wordmark back on its rest frame. */
export function clearSweep(element: SweepTarget): void {
  element.removeAttribute(SWEEPING)
}
