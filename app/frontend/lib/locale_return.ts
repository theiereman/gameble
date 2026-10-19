import { inLocale, ROUTED_LOCALES, routedLocaleOf, sessionTrailStorage, type TrailStorage } from "./history_trail"

export const LOCALE_CHOICE_KEY = "gameble:locale-choice"
export const SHOWN_SINCE_LIMIT = 100

export type LocaleChoice = { locale: string; shownSince: string[] }

function pageOf(address: URL): string {
  return address.pathname + address.search
}

export function addressInChosenLocale(href: string, choice: LocaleChoice | null): string | null {
  if (!choice || !ROUTED_LOCALES.includes(choice.locale)) return null
  const address = new URL(href)
  const locale = routedLocaleOf(address.pathname)
  if (!locale || locale === choice.locale || choice.shownSince.includes(pageOf(address))) return null
  address.pathname = inLocale(address.pathname, choice.locale)
  return address.href
}

export function readLocaleChoice(storage: TrailStorage | null): LocaleChoice | null {
  try {
    const parsed: unknown = JSON.parse(storage?.getItem(LOCALE_CHOICE_KEY) ?? "null")
    if (!parsed || typeof parsed !== "object") return null
    const { locale, shownSince } = parsed as Record<string, unknown>
    if (typeof locale !== "string" || !Array.isArray(shownSince)) return null
    return { locale, shownSince: shownSince.filter((page): page is string => typeof page === "string") }
  } catch {
    return null
  }
}

function writeLocaleChoice(choice: LocaleChoice, storage: TrailStorage | null): void {
  try {
    storage?.setItem(LOCALE_CHOICE_KEY, JSON.stringify(choice))
  } catch {
    // Refused: a return through history keeps the language of its address.
  }
}

export function rememberLocaleChoice(href: string, storage: TrailStorage | null): void {
  const locale = routedLocaleOf(new URL(href).pathname)
  if (locale) writeLocaleChoice({ locale, shownSince: [] }, storage)
}

export function rememberShownPage(href: string, storage: TrailStorage | null): void {
  const choice = readLocaleChoice(storage)
  const address = new URL(href)
  const locale = routedLocaleOf(address.pathname)
  if (!choice || !locale || locale === choice.locale) return
  const page = pageOf(address)
  const shownSince = [...choice.shownSince.filter((shown) => shown !== page), page].slice(-SHOWN_SINCE_LIMIT)
  writeLocaleChoice({ locale: choice.locale, shownSince }, storage)
}

export function keepLocaleOnReturn(): void {
  const storage = sessionTrailStorage()
  let firstLoad = true

  const returnInChosenLocale = (href: string): boolean => {
    const address = addressInChosenLocale(href, readLocaleChoice(storage))
    if (address) restoreEntryAt(address)
    return address !== null
  }

  document.addEventListener("turbo:click", (event) => {
    const link = (event.target as Element).closest("[data-locale-choice]")
    if (link) rememberLocaleChoice((event as CustomEvent<{ url: string }>).detail.url, storage)
  })
  document.addEventListener("turbo:visit", (event) => {
    const { url, action } = (event as CustomEvent<{ url: string; action: string }>).detail
    // Turbo moves its restoration index to the popped entry only after this event.
    if (action === "restore") queueMicrotask(() => returnInChosenLocale(url))
  })
  document.addEventListener("turbo:load", () => {
    const returned = firstLoad && arrivedThroughHistory()
    firstLoad = false
    if (returned && returnInChosenLocale(location.href)) return
    rememberShownPage(location.href, storage)
  })
  window.addEventListener("pageshow", (event) => {
    if (event.persisted && !returnInChosenLocale(location.href)) rememberShownPage(location.href, storage)
  })
  document.addEventListener("turbo:render", showLanguageOfAddress)
}

// A cached snapshot is rendered under the <html lang> of the page it replaces.
function showLanguageOfAddress(): void {
  const locale = routedLocaleOf(location.pathname)
  if (locale) document.documentElement.lang = locale
}

// Turbo scrolls to an entry's recorded position only on a restore visit started by popstate.
function restoreEntryAt(address: string): void {
  const state: unknown = history.state
  if (!(state as { turbo?: unknown } | null)?.turbo) {
    window.Turbo.visit(address, { action: "replace" })
    return
  }
  history.replaceState(state, "", address)
  window.dispatchEvent(new PopStateEvent("popstate", { state }))
}

function arrivedThroughHistory(): boolean {
  const [navigation] = performance.getEntriesByType("navigation") as PerformanceNavigationTiming[]
  return navigation?.type === "back_forward"
}
