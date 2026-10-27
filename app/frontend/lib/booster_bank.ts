import type { BoosterBank, BoosterPhase, Layout } from "./booster_types"

export type FetchBank = {
  url: string
  fetch?: typeof globalThis.fetch
}

export async function fetchBank({ url, fetch: send = globalThis.fetch }: FetchBank): Promise<BoosterBank | null> {
  let response: Response
  try {
    response = await send(url, { method: "GET", headers: { Accept: "application/json" }, credentials: "same-origin" })
  } catch {
    return null
  }
  if (!response.ok) return null

  let body: unknown
  try {
    body = await response.json()
  } catch {
    return null
  }
  if (!isRecord(body) || !isBank(body.bank)) return null
  const { available, reserveFull, nextAvailableAt, serverTime, nextPackSize } = body.bank
  return { available, reserveFull, nextAvailableAt, serverTime, nextPackSize }
}

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value)

function isBank(value: unknown): value is BoosterBank {
  return (
    isRecord(value) &&
    typeof value.available === "number" &&
    typeof value.reserveFull === "boolean" &&
    (value.nextAvailableAt === null || typeof value.nextAvailableAt === "string") &&
    typeof value.serverTime === "string" &&
    (value.nextPackSize === null || typeof value.nextPackSize === "number")
  )
}

export function handPutAway(layout: Layout, revealed: readonly boolean[], stored: readonly boolean[]): boolean {
  const done = layout === "phone" ? stored : revealed
  return done.length > 0 && done.every(Boolean)
}

export type ScreenMoment = {
  phase: BoosterPhase
  idle: boolean
  handPutAway: boolean
}

export function atZero({ phase, idle, handPutAway }: ScreenMoment): "page" | "bank" | "owe" {
  if (!idle) return "owe"
  if (phase === "sealed" || phase === "empty") return "page"
  if (phase === "dealt" && handPutAway) return "bank"
  return "owe"
}

export function owedBankDue({ phase, idle, handPutAway }: ScreenMoment): boolean {
  return idle && phase !== "opening" && (phase !== "dealt" || handPutAway)
}

export function phaseForBank(phase: BoosterPhase, available: number): BoosterPhase {
  if (phase !== "sealed" && phase !== "empty") return phase
  return available > 0 ? "sealed" : "empty"
}
