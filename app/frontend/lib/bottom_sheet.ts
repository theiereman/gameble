export const DISMISS_DISTANCE = 96

export function dragOffset(startY: number, currentY: number): number {
  return Math.max(0, currentY - startY)
}

export function dismisses(offset: number, sheetHeight: number): boolean {
  return offset > 0 && offset >= Math.min(DISMISS_DISTANCE, sheetHeight / 3)
}

export function visitLeavesPage(visit: unknown): boolean {
  return !(typeof visit === "object" && visit !== null && "willRender" in visit && visit.willRender === false)
}

export function focusWrapTarget<T>(focusables: readonly T[], active: T | null, backwards: boolean): T | undefined {
  const first = focusables[0]
  const last = focusables[focusables.length - 1]
  if (first === undefined || last === undefined) return undefined
  const inside = active !== null && focusables.includes(active)
  if (backwards) return !inside || active === first ? last : undefined
  return !inside || active === last ? first : undefined
}
