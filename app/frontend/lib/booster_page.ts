import { layoutFor } from "./booster_rules"
import { NARROW_QUERY, PHONE_QUERY, type Layout } from "./booster_types"

export function readLayout(): Layout {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") return "wide"
  return layoutFor(window.matchMedia(PHONE_QUERY).matches, window.matchMedia(NARROW_QUERY).matches)
}

export const PACK_PARAM = "pack"

export const CELEBRATION_PARAM = "celebration"

export function cardHref(cardUrl: string, slug: string, token: string, index: number): string {
  const url = new URL(cardUrl.replace("SLUG", encodeURIComponent(slug)), "http://booster.invalid")
  url.searchParams.set(PACK_PARAM, token)
  url.searchParams.set("slot", String(index + 1))
  return `${url.pathname}${url.search}`
}

export function withPack(href: string, token: string | null, celebration = false): string {
  const url = new URL(href)
  if (token === null) {
    url.searchParams.delete(PACK_PARAM)
    url.searchParams.delete(CELEBRATION_PARAM)
  } else {
    url.searchParams.set(PACK_PARAM, token)
    if (celebration) url.searchParams.set(CELEBRATION_PARAM, "1")
  }
  return url.toString()
}

export const celebrationMarked = (href: string): boolean => new URL(href).searchParams.has(CELEBRATION_PARAM)

export const celebrationRemembered = (): boolean => typeof location !== "undefined" && celebrationMarked(location.href)

export function rememberPack(token: string | null, celebration = false): void {
  const href = withPack(location.href, token, celebration)
  if (href !== location.href) history.replaceState(history.state, "", href)
}

// A UUID for the idempotency key (crypto.randomUUID needs a secure context).
export function newKey(): string {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID()
  const bytes = crypto.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

export function csrfToken(): string | null {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || null
}

type TurboVisit = { visit(location: string, options?: { action?: "advance" | "replace" }): void }

export function visit(url: string): void {
  const turbo = (window as unknown as { Turbo?: TurboVisit }).Turbo
  if (turbo) turbo.visit(url)
  else window.location.assign(url)
}

export function refreshPage(): void {
  const turbo = (window as unknown as { Turbo?: TurboVisit }).Turbo
  if (turbo) turbo.visit(location.href, { action: "replace" })
  else location.reload()
}
