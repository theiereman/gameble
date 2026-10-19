import { inLocale, sessionTrailStorage, type TrailStorage } from "./history_trail"

export const SHOWN_LOCALE_KEY = "gameble:shown-locale"
export const ROUTED_LOCALES = ["en", "fr"]

export function routedLocaleOf(pathname: string): string | null {
  const segment = pathname.split("/")[1] ?? ""
  return ROUTED_LOCALES.includes(segment) ? segment : null
}

export function addressInShownLocale(href: string, shownLocale: string | null): string | null {
  const address = new URL(href)
  const locale = routedLocaleOf(address.pathname)
  if (!locale || !shownLocale || !ROUTED_LOCALES.includes(shownLocale) || locale === shownLocale) return null
  address.pathname = inLocale(address.pathname, shownLocale)
  return address.href
}

export function readShownLocale(storage: TrailStorage | null): string | null {
  try {
    return storage?.getItem(SHOWN_LOCALE_KEY) ?? null
  } catch {
    return null
  }
}

export function rememberShownLocale(pathname: string, storage: TrailStorage | null): void {
  const locale = routedLocaleOf(pathname)
  if (!locale) return
  try {
    storage?.setItem(SHOWN_LOCALE_KEY, locale)
  } catch {
    // Refused: a return through history keeps the language of its address.
  }
}

export function keepLocaleOnReturn(): void {
  const storage = sessionTrailStorage()
  let firstLoad = true

  const returnInShownLocale = (href: string): boolean => {
    const address = addressInShownLocale(href, readShownLocale(storage))
    if (address) window.Turbo.visit(address, { action: "replace" })
    return address !== null
  }

  document.addEventListener("turbo:visit", (event) => {
    const { url, action } = (event as CustomEvent<{ url: string; action: string }>).detail
    // Turbo moves its restoration index to the popped entry only after this event.
    if (action === "restore") queueMicrotask(() => returnInShownLocale(url))
  })
  document.addEventListener("turbo:load", () => {
    const returned = firstLoad && arrivedThroughHistory()
    firstLoad = false
    if (returned && returnInShownLocale(location.href)) return
    rememberShownLocale(location.pathname, storage)
  })
  window.addEventListener("pageshow", (event) => {
    if (event.persisted && !returnInShownLocale(location.href)) rememberShownLocale(location.pathname, storage)
  })
}

function arrivedThroughHistory(): boolean {
  const [navigation] = performance.getEntriesByType("navigation") as PerformanceNavigationTiming[]
  return navigation?.type === "back_forward"
}
