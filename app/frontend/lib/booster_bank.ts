import type { BoosterBank, BoosterPhase, HeldCapsules, Layout, Reserve } from "./booster_types"
import { isHeld } from "./opening"
import type { QueuedOpening } from "./opening_queue"

export const RESERVES: readonly Reserve[] = ["standard", "special"]

export const reserveCount = (bank: BoosterBank, reserve: Reserve): number =>
  reserve === "special" ? bank.special : bank.available

export const otherReserve = (reserve: Reserve): Reserve => (reserve === "special" ? "standard" : "special")

export function bankAfterHeld(bank: BoosterBank, reserve: Reserve): BoosterBank {
  const standard = reserve === "standard"
  return {
    ...bank,
    available: standard ? Math.max(0, bank.available - 1) : bank.available,
    special: standard ? bank.special : Math.max(0, bank.special - 1),
    openable: Math.max(0, bank.openable - 1),
    reserveFull: standard ? false : bank.reserveFull,
  }
}

export function countsKept(server: BoosterBank, local: BoosterBank, reserves: readonly Reserve[]): BoosterBank {
  const available = reserves.includes("standard") ? local.available : server.available
  const special = reserves.includes("special") ? local.special : server.special
  const openable = Math.max(0, server.openable + available - server.available + special - server.special)
  return { ...server, available, special, openable }
}

export type HeldBank = Readonly<{ bank: BoosterBank; held: HeldCapsules }>

export function heldSkippingQueued(
  { bank, held }: HeldBank,
  confirming: readonly QueuedOpening[],
  reserves: readonly Reserve[] = RESERVES,
): HeldBank {
  return reserves.reduce<HeldBank>(
    (after, reserve) => {
      const capsule = after.held[reserve]
      if (!capsule || !confirming.some(({ token }) => token === capsule.pack.token)) return after
      return { bank: bankAfterHeld(after.bank, reserve), held: { ...after.held, [reserve]: null } }
    },
    { bank, held },
  )
}

export function heldFrom(value: unknown): HeldCapsules {
  const record = isRecord(value) ? value : {}
  return {
    standard: isHeld(record.standard) ? record.standard : null,
    special: isHeld(record.special) ? record.special : null,
  }
}

export type BankAnswer = Readonly<{ bank: BoosterBank; held: HeldCapsules | null }>

export type FetchBank = {
  url: string
  fetch?: typeof globalThis.fetch
}

export async function fetchBank({ url, fetch: send = globalThis.fetch }: FetchBank): Promise<BankAnswer | null> {
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
  const {
    available,
    special,
    openable,
    reserveFull,
    nextSpecialKind,
    nextAvailableAt,
    serverTime,
    nextPackSize,
    nextSpecialSize,
  } = body.bank
  return {
    bank: {
      available,
      special,
      openable,
      reserveFull,
      nextSpecialKind,
      nextAvailableAt,
      serverTime,
      nextPackSize,
      nextSpecialSize,
    },
    held: isRecord(body.held) ? heldFrom(body.held) : null,
  }
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

function isBank(value: unknown): value is BoosterBank {
  return (
    isRecord(value) &&
    typeof value.available === "number" &&
    typeof value.special === "number" &&
    typeof value.openable === "number" &&
    typeof value.reserveFull === "boolean" &&
    (value.nextSpecialKind === null || typeof value.nextSpecialKind === "string") &&
    (value.nextAvailableAt === null || typeof value.nextAvailableAt === "string") &&
    typeof value.serverTime === "string" &&
    (value.nextPackSize === null || typeof value.nextPackSize === "number") &&
    (value.nextSpecialSize === null || typeof value.nextSpecialSize === "number")
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

export function atZero({ phase, idle, handPutAway }: ScreenMoment): "bank" | "owe" {
  if (!idle) return "owe"
  if (phase === "sealed" || phase === "empty") return "bank"
  if (phase === "dealt" && handPutAway) return "bank"
  return "owe"
}

export function owedBankDue({ phase, idle, handPutAway }: ScreenMoment): boolean {
  return idle && phase !== "opening" && (phase !== "dealt" || handPutAway)
}

export function phaseForBank(phase: BoosterPhase, openable: number): BoosterPhase {
  if (phase !== "sealed" && phase !== "empty") return phase
  return openable > 0 ? "sealed" : "empty"
}
