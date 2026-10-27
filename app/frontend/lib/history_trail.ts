// Turbo's restoration index to the page shown at it, kept in sessionStorage and reset on each full document load.
// It lets a contextual back go through history to an earlier page, and a page shown again focus the link it came from.
// Entries from other documents of the tab cannot be trusted; any storage error leaves the trail empty.

export const TRAIL_KEY = "gameble:history-trail"
export const TRAIL_SPAN = 100
export const ROUTED_LOCALES = ["en", "fr"]

export type TrailStorage = Pick<Storage, "getItem" | "setItem">
export type TrailEntry = { pathname: string; label?: string; labels?: Record<string, string> }
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
  const { pathname, label, labels } = entry as Record<string, unknown>
  if (typeof pathname !== "string" || (label !== undefined && typeof label !== "string")) return false
  if (labels === undefined) return true
  return !!labels && typeof labels === "object" && !Array.isArray(labels) &&
    Object.values(labels as Record<string, unknown>).every((value) => typeof value === "string")
}

export function resetTrail(storage: TrailStorage | null): void {
  if (!storage) return
  try {
    storage.setItem(TRAIL_KEY, "{}")
  } catch {
  }
}

export function recordEntry(
  index: number,
  pathname: string,
  storage: TrailStorage | null,
  label?: string | null,
  labels?: Record<string, string> | null,
): void {
  if (!storage) return
  const trail = readTrail(storage)
  const entry: TrailEntry = { pathname }
  if (label) entry.label = label
  if (labels && Object.keys(labels).length > 0) entry.labels = labels
  trail[index] = entry
  for (const key of Object.keys(trail)) {
    if (Math.abs(Number(key) - index) > TRAIL_SPAN) delete trail[key]
  }
  try {
    storage.setItem(TRAIL_KEY, JSON.stringify(trail))
  } catch {
  }
}

/** How many entries back the nearest earlier entry showing `pathname`, in either language, is from `index`; null when none. */
export function stepsBackTo(pathname: string, index: number, storage: TrailStorage | null): number | null {
  const trail = readTrail(storage)
  for (let earlier = index - 1; earlier >= Math.max(0, index - TRAIL_SPAN); earlier--) {
    const recorded = trail[earlier]?.pathname
    if (recorded !== undefined && samePage(recorded, pathname)) return index - earlier
  }
  return null
}

function samePage(recorded: string, pathname: string): boolean {
  if (recorded === pathname) return true
  const locale = routedLocaleOf(pathname)
  return locale !== null && routedLocaleOf(recorded) !== null && inLocale(recorded, locale) === pathname
}

/** The pathname recorded right after `index`: the page the user came back from. */
export function entryAfter(index: number, storage: TrailStorage | null): string | null {
  return readTrail(storage)[index + 1]?.pathname ?? null
}

export type PreviousScreen = { label: string; pathname: string; steps: number }

/** The nearest entry before `index` showing another screen than `currentLabel`; null when unknown or unlabelled. */
export function previousScreen(trail: Trail, index: number, currentLabel: string | null, currentPathname: string): PreviousScreen | null {
  const locale = localeOf(currentPathname)
  for (let earlier = index - 1; earlier >= Math.max(0, index - TRAIL_SPAN); earlier--) {
    const entry = trail[earlier]
    if (!entry) return null
    const localeChanged = localeOf(entry.pathname) !== locale
    const label = localeChanged ? entry.labels?.[locale] : entry.label
    if (!label) return null
    if (currentLabel && label === currentLabel) continue
    return {
      label,
      pathname: localeChanged ? inLocale(entry.pathname, locale) : entry.pathname,
      steps: index - earlier,
    }
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

export function currentScreenLabels(): Record<string, string> | null {
  const raw = document.querySelector<HTMLElement>(".top-bar")?.dataset.screenLabels
  if (!raw) return null
  try {
    const parsed: unknown = JSON.parse(raw)
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null
    const labels: Record<string, string> = {}
    for (const [locale, label] of Object.entries(parsed as Record<string, unknown>)) {
      if (typeof label === "string") labels[locale] = label
    }
    return Object.keys(labels).length > 0 ? labels : null
  } catch {
    return null
  }
}

export function routedLocaleOf(pathname: string): string | null {
  const segment = pathname.split("/")[1] ?? ""
  return ROUTED_LOCALES.includes(segment) ? segment : null
}

function localeOf(pathname: string): string {
  return pathname.split("/")[1] ?? ""
}

function pathWithoutLocale(pathname: string): string {
  return pathname.replace(/^\/[^/]*/, "")
}

export function inLocale(pathname: string, locale: string): string {
  return `/${locale}${pathWithoutLocale(pathname)}`
}
