export const NEAR_START_MARGIN = "50% 0px 0px 0px"

export type NewestPillState = {
  readerScrolled: boolean
  scrollY: number
  viewportHeight: number
  newerLeft: boolean
}

export function newestPillShown({ readerScrolled, scrollY, viewportHeight, newerLeft }: NewestPillState): boolean {
  if (!readerScrolled) return false

  return newerLeft || scrollY > viewportHeight
}

export function newestAction(live: boolean, newerLeft: boolean): "scroll" | "visit" {
  return live && !newerLeft ? "scroll" : "visit"
}

export function anchorShift(topBefore: number, topAfter: number): number {
  return Math.round(topAfter - topBefore)
}
