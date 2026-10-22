export const POWER_LINE = 0.85
export const CURRENT_LINE = 0.4
const DRIFT_NEAR = 0.12
const DRIFT_FAR = 0.05

export function crossedPowerLine(top: number, viewportHeight: number): boolean {
  return top <= viewportHeight * POWER_LINE
}

export function currentModuleIndex(tops: number[], viewportHeight: number, atPageEnd = false): number {
  if (atPageEnd) return tops.length - 1
  const line = viewportHeight * CURRENT_LINE
  let current = 0
  tops.forEach((top, index) => {
    if (top <= line) current = index
  })
  return current
}

export function scrollFill(scrollY: number, scrollable: number, segments: number): number {
  if (scrollable <= 0) return 0
  const share = Math.min(Math.max(scrollY / scrollable, 0), 1)
  return Math.round(share * segments)
}

export function driftOffsets(scrollY: number): { near: number; far: number } {
  return { near: DRIFT_NEAR * scrollY, far: DRIFT_FAR * scrollY }
}

export function staggerDelayMs(index: number, stepMs: number): number {
  return index * stepMs
}
