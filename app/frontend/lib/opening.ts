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
  season: number
  tier: Rarity
  coverUrl: string
  title: string
  year: number | null
  /** The card as spoken: "Hades — Supergiant Games, 2020, Roguelite". */
  label: string
  /** The face at each size, rendered on the server (CardComponent): s in the narrow row, m in the wide one, xl on the phone. */
  faces: { s: string; m: string; xl: string }
}

export type OpeningBank = {
  available: number
  reserveFull: boolean
  nextAvailableAt: string | null
  scheduledAt: string[]
  /** The card count of the pack the next opening opens, null when none is available. */
  nextPackSize: number | null
}

/** Every tier name: the metals of earlier seasons, the ranks, complete. The order only breaks a tie between two tiers asking the same count. */
export const SET_TIERS = ["bronze", "silver", "gold", "novice", "apprentice", "adept", "expert", "master", "complete"] as const
export type SetTierName = (typeof SET_TIERS)[number]

/** A tier of a set and the cards it asks for. */
export type SetThreshold = { tier: SetTierName; required: number }

/** A set tier the opening reached: "Roguelike", silver at 16 of its 62 cards. */
export type OpeningSetTier = {
  kind: string
  key: string
  name: string
  tier: SetTierName
  required: number
  total: number
  /** The set's tiers before completion, the fewest cards first. */
  thresholds: SetThreshold[]
  url: string
}

export type OpeningAnswer = {
  pack: { token: string; kind: string; cardBack: string; url: string }
  cards: OpeningCard[]
  bank: OpeningBank
  serverTime: string
  tierCountsBefore: Record<Rarity, number>
  /** Every set tier row the opening inserted, by set then tier. */
  setTiers: OpeningSetTier[]
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

const FACE_SIZES = ["s", "m", "xl"] as const

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value)

function isCard(value: unknown): value is OpeningCard {
  return (
    isRecord(value) &&
    typeof value.slug === "string" &&
    Number.isInteger(value.season) &&
    RARITIES.includes(value.tier as Rarity) &&
    typeof value.title === "string" &&
    typeof value.label === "string" &&
    isRecord(value.faces) &&
    FACE_SIZES.every((size) => typeof (value.faces as Record<string, unknown>)[size] === "string")
  )
}

function isThreshold(value: unknown): value is SetThreshold {
  return isRecord(value) && SET_TIERS.includes(value.tier as SetTierName) && value.tier !== "complete" && Number.isInteger(value.required)
}

function isSetTier(value: unknown): value is OpeningSetTier {
  return (
    isRecord(value) &&
    typeof value.kind === "string" &&
    typeof value.key === "string" &&
    typeof value.name === "string" &&
    SET_TIERS.includes(value.tier as SetTierName) &&
    Number.isInteger(value.required) &&
    Number.isInteger(value.total) &&
    Array.isArray(value.thresholds) &&
    value.thresholds.every(isThreshold) &&
    typeof value.url === "string"
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
    RARITIES.every((tier) => typeof (value.tierCountsBefore as Record<string, unknown>)[tier] === "number") &&
    Array.isArray(value.setTiers) &&
    value.setTiers.every(isSetTier)
  )
}

function refusal(value: unknown): { code: string; message: string } | null {
  if (!isRecord(value) || !isRecord(value.error)) return null
  const { code, message } = value.error
  return typeof code === "string" && typeof message === "string" ? { code, message } : null
}
