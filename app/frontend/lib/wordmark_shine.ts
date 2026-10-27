import { motionReduced } from "./motion"

export const SWEEP_ANIMATION = "wordmark-sweep"
export const SWEEP_STEPS = 22
export const STEP_MS = 40
export const FRAME_ROWS = 9

export const SWEEPING = "data-sweeping"

export type SweepTarget = Pick<Element, "hasAttribute" | "setAttribute" | "removeAttribute">

export function startSweep(element: SweepTarget): boolean {
  if (motionReduced()) {
    clearSweep(element)
    return false
  }
  if (element.hasAttribute(SWEEPING)) return false
  element.setAttribute(SWEEPING, "")
  return true
}

export function endSweep(element: SweepTarget, animationName: string): void {
  if (animationName === SWEEP_ANIMATION) clearSweep(element)
}

export function clearSweep(element: SweepTarget): void {
  element.removeAttribute(SWEEPING)
}
