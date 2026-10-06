// The booster's opening exchange, client side (AD-23; story 8.10): one
// POST to the packs URL in JSON, with the activation's idempotency key and
// the page's CSRF token. The answer is one of three outcomes: the pack
// opened (its cards with their faces), a refusal the server explained
// (`{ error: { code, message } }`), or a failure whose outcome is unknown
// (no answer, an answer that is not the exchange's, a server error), after
// which the same key is sent again. No DOM.
import { RARITIES, type Rarity } from "./card_types"

/** A card of the opened pack, in drawn order (PacksHelper#pack_opening_json). */
export type OpeningCard = {
  slug: string
  tier: Rarity
  coverUrl: string
  title: string
  year: number | null
  /** The card as spoken: "Hades — Supergiant Games, 2020, Roguelite". */
  label: string
  /** The face at each size, rendered on the server (CardComponent). */
  faces: { m: string; xl: string }
}

export type OpeningBank = {
  available: number
  reserveFull: boolean
  nextAvailableAt: string | null
  scheduledAt: string[]
}

export type OpeningAnswer = {
  pack: { token: string; kind: string; cardBack: string; url: string }
  cards: OpeningCard[]
  bank: OpeningBank
  serverTime: string
  tierCountsBefore: Record<Rarity, number>
  unlockedCardBacks: unknown[]
}

export type OpeningResult =
  | { kind: "opened"; answer: OpeningAnswer }
  | { kind: "refused"; code: string; message: string }
  | { kind: "failed" }

export type SendOpening = {
  url: string
  key: string
  /** The page's `meta[name=csrf-token]`, when present. */
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const FAILED: OpeningResult = { kind: "failed" }

export async function sendOpening({ url, key, csrfToken, fetch: send = globalThis.fetch }: SendOpening): Promise<OpeningResult> {
  const headers: Record<string, string> = { Accept: "application/json", "Idempotency-Key": key }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  let response: Response
  try {
    response = await send(url, { method: "POST", headers, credentials: "same-origin" })
  } catch {
    return FAILED
  }
  // A server error may have opened the pack before failing: unknown.
  if (response.status >= 500) return FAILED

  let body: unknown
  try {
    body = await response.json()
  } catch {
    return FAILED
  }
  if (response.ok) return isAnswer(body) ? { kind: "opened", answer: body } : FAILED

  const error = refusal(body)
  return error ? { kind: "refused", ...error } : FAILED
}

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value)

function isCard(value: unknown): value is OpeningCard {
  return (
    isRecord(value) &&
    typeof value.slug === "string" &&
    RARITIES.includes(value.tier as Rarity) &&
    typeof value.title === "string" &&
    typeof value.label === "string" &&
    isRecord(value.faces) &&
    typeof value.faces.m === "string"
  )
}

function isAnswer(value: unknown): value is OpeningAnswer {
  return (
    isRecord(value) &&
    isRecord(value.pack) &&
    Array.isArray(value.cards) &&
    value.cards.length > 0 &&
    value.cards.every(isCard) &&
    isRecord(value.bank) &&
    typeof value.bank.available === "number" &&
    typeof value.serverTime === "string" &&
    isRecord(value.tierCountsBefore) &&
    RARITIES.every((tier) => typeof (value.tierCountsBefore as Record<string, unknown>)[tier] === "number")
  )
}

function refusal(value: unknown): { code: string; message: string } | null {
  if (!isRecord(value) || !isRecord(value.error)) return null
  const { code, message } = value.error
  return typeof code === "string" && typeof message === "string" ? { code, message } : null
}
