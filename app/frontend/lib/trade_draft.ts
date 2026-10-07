import type { Line } from "./trade_board"

export const DRAFT_PREFIX = "gameble:trade-draft:"

export type DraftField = "give" | "take"
export type DraftSides = Partial<Record<DraftField, Line[]>>

type DraftStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">

function browserStorage(): DraftStorage | null {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export function readDraft(key: string, storage: DraftStorage | null = browserStorage()): DraftSides | null {
  if (!storage || !key) return null
  try {
    const raw = storage.getItem(DRAFT_PREFIX + key)
    return raw === null ? null : parseDraft(raw)
  } catch {
    return null
  }
}

export function saveDraft(key: string, sides: DraftSides, storage: DraftStorage | null = browserStorage()): void {
  if (!storage || !key) return
  try {
    storage.setItem(DRAFT_PREFIX + key, JSON.stringify(sides))
  } catch {
    // Storage full or refused: the board still works, unsaved.
  }
}

export function forgetDraft(key: string, storage: DraftStorage | null = browserStorage()): void {
  if (!storage || !key) return
  try {
    storage.removeItem(DRAFT_PREFIX + key)
  } catch {
    // Storage refused: nothing was kept.
  }
}

export function parseDraft(raw: string): DraftSides | null {
  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch {
    return null
  }
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null
  const record = value as Record<string, unknown>
  const sides: DraftSides = {}
  for (const field of ["give", "take"] as const) {
    const lines = record[field]
    if (Array.isArray(lines)) sides[field] = lines.filter(isLine).map(({ key, quantity }) => ({ key, quantity }))
  }
  return sides
}

export function sameLines(a: readonly Line[], b: readonly Line[]): boolean {
  if (a.length !== b.length) return false
  const quantities = new Map(a.map((line) => [line.key, line.quantity]))
  return b.every((line) => quantities.get(line.key) === line.quantity)
}

function isLine(value: unknown): value is Line {
  if (typeof value !== "object" || value === null) return false
  const { key, quantity } = value as Record<string, unknown>
  return typeof key === "string" && key !== "" && typeof quantity === "number" && Number.isInteger(quantity) && quantity > 0
}
