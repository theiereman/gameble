// What the booster island asks of the page around it: an idempotency key
// for the opening, the CSRF token, a visit or a refresh through Turbo (the
// browser's own when Turbo is absent), and the layout the viewport's width
// asks for.
import { NARROW_QUERY, PHONE_QUERY, layoutFor, type Layout } from "./booster"

/** The layout the viewport's width asks for (lib/booster.ts, layoutFor). */
export function readLayout(): Layout {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") return "wide"
  return layoutFor(window.matchMedia(PHONE_QUERY).matches, window.matchMedia(NARROW_QUERY).matches)
}

/** A UUID for the idempotency key (crypto.randomUUID needs a secure context). */
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

/** The screen again from the server, in place (as countdown_controller.ts refreshes the hub). */
export function refreshPage(): void {
  const turbo = (window as unknown as { Turbo?: TurboVisit }).Turbo
  if (turbo) turbo.visit(location.href, { action: "replace" })
  else location.reload()
}
