export type WornBack = { readonly back: string; readonly season: number | null }

export function wornBack(back: string): WornBack {
  return { back, season: null }
}

function seasonOf(value: unknown): number | null | undefined {
  if (value === null || value === undefined) return null
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : undefined
}

export function wear(state: WornBack, detail: unknown): WornBack | null {
  if (typeof detail !== "object" || detail === null) return null
  const { back, season } = detail as { back?: unknown; season?: unknown }
  if (typeof back !== "string" || back === "") return null
  const worn = seasonOf(season)
  if (worn === undefined) return null
  if (back === state.back && worn === state.season) return null
  return { back, season: worn }
}
