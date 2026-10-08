export const TICKER_PIXELS_PER_SECOND = 60
export const TICKER_MIN_SECONDS = 10

export function repeatsToFill(runWidth: number, windowWidth: number): number {
  if (runWidth <= 0) return 1
  return Math.max(1, Math.ceil(windowWidth / runWidth))
}

export function loopSeconds(halfWidth: number, speed: number = TICKER_PIXELS_PER_SECOND): number {
  return Math.max(TICKER_MIN_SECONDS, halfWidth / speed)
}

export function joinQueued<T>(shown: readonly T[], arrived: readonly T[], size: number, keep = 0): T[] {
  const kept = Math.min(Math.max(0, keep), shown.length)
  const joining = arrived.slice(0, Math.max(1, size - kept))
  const joined = [...shown.slice(0, kept), ...joining, ...shown.slice(kept)]
  return joined.slice(0, Math.max(size, kept + joining.length))
}

export function itemsInView(itemStarts: readonly number[], windowWidth: number): number {
  return itemStarts.filter((start) => start < windowWidth).length
}
