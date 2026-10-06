// The pages of this tab's history, by Turbo's restoration index (the
// position Turbo writes in each history entry's state), so a contextual
// back ("◀ Grille"; history_back_controller.ts) can go back through
// history to a page shown earlier, which Turbo then restores at its
// scroll, rather than visit it anew. Kept in sessionStorage and started
// afresh on each full document load (resetTrail), as Turbo's index restarts
// there: only entries of the current Turbo session are trusted. Any storage
// error (private mode, quota) leaves it empty, and the back is a plain visit.
//
// Every page load and every frame visit that changes the URL records
// { index → pathname }: a replaced entry (◀ ▶) overwrites its index, a new
// entry its own. Only entries before the current one are read back: those
// are always the pages history would return to.

export const TRAIL_KEY = "gameble:history-trail"
/** How many entries are kept around the current one, either way. */
export const TRAIL_SPAN = 100

export type TrailStorage = Pick<Storage, "getItem" | "setItem">
export type Trail = Record<string, string>

function read(storage: TrailStorage | null): Trail {
  if (!storage) return {}
  try {
    const parsed: unknown = JSON.parse(storage.getItem(TRAIL_KEY) ?? "{}")
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? (parsed as Trail) : {}
  } catch {
    return {}
  }
}

/**
 * Empties the trail. Called on each full document load: Turbo's restoration
 * index restarts at 0 there, so entries recorded by an earlier document of
 * the tab no longer match the indexes of this one.
 */
export function resetTrail(storage: TrailStorage | null): void {
  if (!storage) return
  try {
    storage.setItem(TRAIL_KEY, "{}")
  } catch {
    // Refused: the trail reads as empty or stale; the back may be a plain visit.
  }
}

/** Records that the entry at `index` shows `pathname`, dropping entries far from it. */
export function recordEntry(index: number, pathname: string, storage: TrailStorage | null): void {
  if (!storage) return
  const trail = read(storage)
  trail[index] = pathname
  for (const key of Object.keys(trail)) {
    if (Math.abs(Number(key) - index) > TRAIL_SPAN) delete trail[key]
  }
  try {
    storage.setItem(TRAIL_KEY, JSON.stringify(trail))
  } catch {
    // Full or refused: the back stays a plain visit.
  }
}

/**
 * How many entries back the nearest earlier entry showing `pathname` is,
 * from the entry at `index`; null when no earlier entry shows it.
 */
export function stepsBackTo(pathname: string, index: number, storage: TrailStorage | null): number | null {
  const trail = read(storage)
  for (let earlier = index - 1; earlier >= Math.max(0, index - TRAIL_SPAN); earlier--) {
    if (trail[earlier] === pathname) return index - earlier
  }
  return null
}

/** The tab's session storage, or null where reading it throws. */
export function sessionTrailStorage(): TrailStorage | null {
  try {
    return window.sessionStorage
  } catch {
    return null
  }
}

/** The current entry's restoration index (Turbo's history state), 0 without one. */
export function currentIndex(): number {
  const index: unknown = (history.state as { turbo?: { restorationIndex?: unknown } } | null)?.turbo?.restorationIndex
  return typeof index === "number" ? index : 0
}
