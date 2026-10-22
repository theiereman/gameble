import { ROUTED_LOCALES } from "./history_trail"

export type SnapshotCache = { clear(): void }

export function isBridgeAddress(href: string): boolean {
  const { pathname } = new URL(href, "https://gameble.invalid")
  return ROUTED_LOCALES.some((locale) => pathname === `/${locale}` || pathname === `/${locale}/`)
}

export function forgetSnapshotsBeforeBridge(href: string, cache: SnapshotCache): boolean {
  if (!isBridgeAddress(href)) return false
  cache.clear()
  return true
}

// Turbo reads its snapshot cache when a visit starts, before turbo:visit, so the guard hooks earlier.
export function keepForeignSnapshotsOffTheBridge(): void {
  document.addEventListener("turbo:before-visit", (event) => {
    forgetSnapshotsBeforeBridge((event as CustomEvent<{ url: string }>).detail.url, window.Turbo.cache)
  })
  window.addEventListener("popstate", () => forgetSnapshotsBeforeBridge(location.href, window.Turbo.cache))
}
