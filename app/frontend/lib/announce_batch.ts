export const ANNOUNCE_INTERVAL_MS = 30_000

export class AnnounceBatch {
  private pending = 0
  private open = false

  constructor(private readonly interval: number = ANNOUNCE_INTERVAL_MS) {}

  add(count: number): number | null {
    if (count <= 0) return null
    this.pending += count
    if (this.open) return null
    this.open = true
    return this.interval
  }

  take(): number {
    const count = this.pending
    this.pending = 0
    this.open = false
    return count
  }
}

export function shouldAnnounce(count: number, { reduced, focusInside }: { reduced: boolean; focusInside: boolean }): boolean {
  return count > 0 && !reduced && !focusInside
}

export function beyondLimit<T>(items: readonly T[], limit: number): T[] {
  return items.slice(Math.max(0, limit))
}
