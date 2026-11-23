export const BOUGHT_GUARD_MS = 400

export function targetsControl(stream: Element, controlId: string): boolean {
  return stream.getAttribute("target") === controlId
}

export function guarded(boughtAt: number | null, now: number): boolean {
  return boughtAt !== null && now - boughtAt < BOUGHT_GUARD_MS
}
