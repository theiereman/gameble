export type StripState = {
  hovered: string | null
  focused: string | null
  latest: "hover" | "focus" | null
}

export const restingStrip: StripState = { hovered: null, focused: null, latest: null }

export function hovered(state: StripState, key: string): StripState {
  return { ...state, hovered: key, latest: "hover" }
}

export function unhovered(state: StripState, key: string): StripState {
  return state.hovered === key ? { ...state, hovered: null } : state
}

export function focused(state: StripState, key: string): StripState {
  return { ...state, focused: key, latest: "focus" }
}

export function blurred(state: StripState): StripState {
  return { ...state, focused: null }
}

export function stripTarget(state: StripState, active: string): string {
  if (state.hovered && state.focused) return state.latest === "hover" ? state.hovered : state.focused
  return state.hovered ?? state.focused ?? active
}

export function shownSeason(seasons: readonly number[], worn: number | null): number | null {
  if (worn !== null && seasons.includes(worn)) return worn
  return seasons.length > 0 ? Math.max(...seasons) : null
}

export function isCurrentChoice(
  choice: { back: string; season: number | null },
  active: { back: string; season: number | null },
): boolean {
  return choice.back === active.back && (choice.season === null || choice.season === active.season)
}

export type ChoiceResult =
  { kind: "chosen"; back: string; season: number | null; announcement: string } | { kind: "failed" }

export type SendChoice = {
  url: string
  back: string
  season: number | null
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

export async function sendChoice({
  url,
  back,
  season,
  csrfToken,
  fetch: send = globalThis.fetch,
}: SendChoice): Promise<ChoiceResult> {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken

  try {
    const response = await send(url, {
      method: "PATCH",
      headers,
      body: JSON.stringify(season === null ? { back } : { back, season }),
      credentials: "same-origin",
    })
    if (!response.ok) return { kind: "failed" }
    const body: unknown = await response.json()
    if (!isRecord(body) || typeof body.back !== "string" || typeof body.announcement !== "string")
      return { kind: "failed" }
    return {
      kind: "chosen",
      back: body.back,
      season: typeof body.season === "number" ? body.season : null,
      announcement: body.announcement,
    }
  } catch {
    return { kind: "failed" }
  }
}
