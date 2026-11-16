export type CoverageCell = { call: string; best: number | null; gap: boolean }

export type Placement = { slot: number; ref: string }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

const isCell = (value: unknown): value is CoverageCell =>
  isRecord(value) &&
  typeof value.call === "string" &&
  (value.best === null || typeof value.best === "number") &&
  typeof value.gap === "boolean"

const isPlacement = (value: unknown): value is Placement =>
  isRecord(value) && typeof value.slot === "number" && typeof value.ref === "string"

export function coverageOf(value: unknown): CoverageCell[] | null {
  return Array.isArray(value) ? value.filter(isCell) : null
}

export function placementsOf(value: unknown): Placement[] {
  return Array.isArray(value) ? value.filter(isPlacement) : []
}
