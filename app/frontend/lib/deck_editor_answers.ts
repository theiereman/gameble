export type CoverageCell = { call: string; best: number | null; gap: boolean; many: boolean }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

const isCell = (value: unknown): value is CoverageCell =>
  isRecord(value) &&
  typeof value.call === "string" &&
  (value.best === null || typeof value.best === "number") &&
  typeof value.gap === "boolean" &&
  typeof value.many === "boolean"

export function coverageOf(value: unknown): CoverageCell[] | null {
  return Array.isArray(value) ? value.filter(isCell) : null
}
