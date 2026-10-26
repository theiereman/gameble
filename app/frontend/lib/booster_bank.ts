// The booster screen's bank read again from the server, and what its
// countdown's zero does, a dealt hand never refreshed away. No DOM.
import type { BoosterBank, BoosterPhase, Layout } from "./booster"

export type FetchBank = {
  /** The booster screen in JSON (the root's bankUrl value). */
  url: string
  fetch?: typeof globalThis.fetch
}

/** The server's bank now, or null when it could not be read. */
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

/** The hand is put away: every card revealed in a row, every card stored on the phone. */
export function handPutAway(layout: Layout, revealed: readonly boolean[], stored: readonly boolean[]): boolean {
  const done = layout === "phone" ? stored : revealed
  return done.length > 0 && done.every(Boolean)
}

export type ScreenMoment = {
  phase: BoosterPhase
  /** Nothing runs: no opening, no reveal, no "reveal all", no store. */
  idle: boolean
  handPutAway: boolean
}

/**
 * What the countdown's zero does: the page refreshed with no hand at rest,
 * the bank fetched with a hand put away at rest, else a fetch owed.
 */
export function atZero({ phase, idle, handPutAway }: ScreenMoment): "page" | "bank" | "owe" {
  if (!idle) return "owe"
  if (phase === "sealed" || phase === "empty") return "page"
  if (phase === "dealt" && handPutAway) return "bank"
  return "owe"
}

/** An owed fetch is made once nothing runs and no hand waits to be put away. */
export function owedBankDue({ phase, idle, handPutAway }: ScreenMoment): boolean {
  return idle && phase !== "opening" && (phase !== "dealt" || handPutAway)
}

/** The phase a fresh bank leaves: the canister follows the count; a hand or an opening stays. */
export function phaseForBank(phase: BoosterPhase, available: number): BoosterPhase {
  if (phase !== "sealed" && phase !== "empty") return phase
  return available > 0 ? "sealed" : "empty"
}
