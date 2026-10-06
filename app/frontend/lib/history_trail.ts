// The pages of this tab's history, by Turbo's restoration index (the
// position Turbo writes in each history entry's state), so a contextual
// back ("◀ Grille"; history_back_controller.ts) can go back through
// history to a page shown earlier, which Turbo then restores at its
// scroll, rather than visit it anew, and a page shown again can focus the
// link to the page the user came back from. Kept in sessionStorage and
// started afresh on each full document load (resetTrail): Turbo reads its
// index back from history.state there (a reload, a back/forward document
// load), but the pages recorded by earlier documents of the tab, or by
// entries this document never saw, cannot be trusted to still match those
// indexes; only entries of the current document are. A reload therefore
// loses the trail, and the back falls back to a plain visit. Any storage
// error (private mode, quota) leaves it empty, and the back is a plain visit.
//
// Every page load and every frame visit that changes the URL records
// { index → pathname }: a replaced entry (◀ ▶) overwrites its index, a new
// entry its own. Entries before the current one are the pages history
// would return to; the entry right after it, the page the user just came
// back from.

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
 * Empties the trail. Called on each full document load, and when the page
 * comes back from the back/forward cache: entries recorded by another
 * document of the tab may name other pages at the same indexes.
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

/**
 * How many entries a contextual back goes back from the entry at `index`:
 * to the nearest earlier entry showing `pathname` (its href's), or to an
 * alternate only when that is the entry right before the current one (the
 * page the detail was opened from: ◀ ▶ only replace entries, so it stays
 * one step back). Null when neither is: the link visits its href.
 */
export function backSteps(pathname: string, alternates: readonly string[], index: number, storage: TrailStorage | null): number | null {
  const steps = stepsBackTo(pathname, index, storage)
  if (steps === 1) return steps
  if (alternates.includes(read(storage)[index - 1] ?? "")) return 1
  return steps
}

/**
 * The pathname recorded for the entry right after the one at `index` (the
 * page the user came back from by a restore visit), or null when none is.
 */
export function entryAfter(index: number, storage: TrailStorage | null): string | null {
  return read(storage)[index + 1] ?? null
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
