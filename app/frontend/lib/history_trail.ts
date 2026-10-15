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
// { index → pathname and screen label }: a replaced entry (◀ ▶) overwrites
// its index, a new entry its own. Entries before the current one are the
// pages history would return to; the nearest of them showing another screen,
// the one the desktop back button names (earlier pages of the current screen,
// such as the collection's other pages, are skipped); the entry right after
// it, the page the user just came back from. The hub and unnamed screens
// record no label.

export const TRAIL_KEY = "gameble:history-trail"
/** How many entries are kept around the current one, either way. */
export const TRAIL_SPAN = 100

export type TrailStorage = Pick<Storage, "getItem" | "setItem">
export type TrailEntry = { pathname: string; label?: string }
export type Trail = Record<string, TrailEntry>

export function readTrail(storage: TrailStorage | null): Trail {
  if (!storage) return {}
  try {
    const parsed: unknown = JSON.parse(storage.getItem(TRAIL_KEY) ?? "{}")
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {}
    const trail: Trail = {}
    for (const [index, entry] of Object.entries(parsed as Record<string, unknown>)) {
      if (isTrailEntry(entry)) trail[index] = entry
    }
    return trail
  } catch {
    return {}
  }
}

function isTrailEntry(entry: unknown): entry is TrailEntry {
  if (!entry || typeof entry !== "object") return false
  const { pathname, label } = entry as Record<string, unknown>
  return typeof pathname === "string" && (label === undefined || typeof label === "string")
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

/**
 * Records that the entry at `index` shows `pathname`, named `label` when the
 * screen has a short name, dropping entries far from it.
 */
export function recordEntry(index: number, pathname: string, storage: TrailStorage | null, label?: string | null): void {
  if (!storage) return
  const trail = readTrail(storage)
  trail[index] = label ? { pathname, label } : { pathname }
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
  const trail = readTrail(storage)
  for (let earlier = index - 1; earlier >= Math.max(0, index - TRAIL_SPAN); earlier--) {
    if (trail[earlier]?.pathname === pathname) return index - earlier
  }
  return null
}

/**
 * The pathname recorded for the entry right after the one at `index` (the
 * page the user came back from by a restore visit), or null when none is.
 */
export function entryAfter(index: number, storage: TrailStorage | null): string | null {
  return readTrail(storage)[index + 1]?.pathname ?? null
}

export type PreviousScreen = { label: string; pathname: string; steps: number }

/**
 * The nearest entry before the one at `index` showing a screen other than
 * `currentLabel`, skipping the entries of the current screen; null when that
 * entry is unknown, its screen has no label (the hub), or it was read in
 * another language than `currentPathname`'s.
 */
export function previousScreen(trail: Trail, index: number, currentLabel: string | null, currentPathname: string): PreviousScreen | null {
  for (let earlier = index - 1; earlier >= Math.max(0, index - TRAIL_SPAN); earlier--) {
    const entry = trail[earlier]
    if (!entry) return null
    if (localeOf(entry.pathname) !== localeOf(currentPathname)) return null
    if (currentLabel && entry.label === currentLabel) continue
    if (!entry.label) return null
    return { label: entry.label, pathname: entry.pathname, steps: index - earlier }
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

/** The short name of the screen shown, carried by the top bar; null for the hub and unnamed screens. */
export function currentScreenLabel(): string | null {
  return document.querySelector<HTMLElement>(".top-bar")?.dataset.screenLabel || null
}

function localeOf(pathname: string): string {
  return pathname.split("/")[1] ?? ""
}
