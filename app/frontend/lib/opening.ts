import { RARITIES, type Rarity } from "./card_types"

export type OpeningCard = {
  slug: string
  season: number
  tier: Rarity
  coverUrl: string
  title: string
  year: number | null
  label: string
  faces: { s: string; m: string; xl: string }
}

export type OpeningBank = {
  available: number
  special: number
  openable: number
  reserveFull: boolean
  nextSpecialKind: string | null
  nextAvailableAt: string | null
  scheduledAt: string[]
  nextPackSize: number | null
}

export const SET_TIERS = [
  "bronze",
  "silver",
  "gold",
  "novice",
  "apprentice",
  "adept",
  "expert",
  "master",
  "complete",
] as const
export type SetTierName = (typeof SET_TIERS)[number]

export type SetThreshold = { tier: SetTierName; required: number }

export type OpeningSetTier = {
  kind: string
  key: string
  name: string
  tier: SetTierName
  required: number
  held: number
  total: number
  thresholds: SetThreshold[]
  url: string
}

export type CardBackView = { key: string; urls: { s: string; m: string; xl: string } | null }

export type OpeningAnswer = {
  pack: { token: string; kind: string; cardBack: CardBackView; url: string }
  cards: OpeningCard[]
  bank: OpeningBank
  serverTime: string
  tierCountsBefore: Record<Rarity, number>
  setTiers: OpeningSetTier[]
  unlockedCardBacks: unknown[]
}

export type OpeningResult =
  { kind: "opened"; answer: OpeningAnswer } | { kind: "refused"; code: string; message: string } | { kind: "failed" }

export type SendOpening = {
  url: string
  reserve: string
  key: string
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const FAILED: OpeningResult = { kind: "failed" }

export async function sendOpening({
  url,
  reserve,
  key,
  csrfToken,
  fetch: send = globalThis.fetch,
}: SendOpening): Promise<OpeningResult> {
  const headers: Record<string, string> = { Accept: "application/json", "Idempotency-Key": key }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  let response: Response
  try {
    response = await send(`${url}?${new URLSearchParams({ reserve })}`, {
      method: "POST",
      headers,
      credentials: "same-origin",
    })
  } catch {
    return FAILED
  }
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

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

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
  return (
    isRecord(value) &&
    SET_TIERS.includes(value.tier as SetTierName) &&
    value.tier !== "complete" &&
    Number.isInteger(value.required)
  )
}

function isSetTier(value: unknown): value is OpeningSetTier {
  return (
    isRecord(value) &&
    typeof value.kind === "string" &&
    typeof value.key === "string" &&
    typeof value.name === "string" &&
    SET_TIERS.includes(value.tier as SetTierName) &&
    Number.isInteger(value.required) &&
    Number.isInteger(value.held) &&
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
    typeof value.bank.special === "number" &&
    typeof value.bank.openable === "number" &&
    (value.bank.nextSpecialKind === null || typeof value.bank.nextSpecialKind === "string") &&
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
