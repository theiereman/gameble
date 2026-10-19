export const PICKER_PAGE = 36

const FACES_TIMEOUT_MS = 10_000

export type Faces = ReadonlyMap<string, string>

export const shownFor = (index: number) => Math.ceil((Math.max(0, index) + 1) / PICKER_PAGE) * PICKER_PAGE

export const nextPage = (shown: number) => shown + PICKER_PAGE

export function missingFaces(keys: readonly string[], known: Faces, pending: ReadonlySet<string>): string[] {
  return [...new Set(keys)].filter((key) => !known.has(key) && !pending.has(key))
}

export function batches<Item>(items: readonly Item[], size: number): Item[][] {
  const step = Math.max(1, Math.trunc(size))
  return Array.from({ length: Math.ceil(items.length / step) }, (_, at) => items.slice(at * step, (at + 1) * step))
}

export function facesUrl(base: string, keys: readonly string[]): string {
  const query = new URLSearchParams(keys.map((key) => ["keys[]", key]))
  return `${base}${base.includes("?") ? "&" : "?"}${query}`
}

export function facesFrom(body: unknown): Record<string, string> {
  const faces = typeof body === "object" && body !== null ? (body as { faces?: unknown }).faces : null
  if (typeof faces !== "object" || faces === null || Array.isArray(faces)) return {}
  return Object.fromEntries(Object.entries(faces).filter((entry): entry is [string, string] => typeof entry[1] === "string"))
}

type FetchFaces = { url: string; fetch?: typeof fetch; timeout?: number }

export async function fetchFaces({ url, fetch: send = globalThis.fetch, timeout = FACES_TIMEOUT_MS }: FetchFaces): Promise<Record<string, string>> {
  try {
    const signal = AbortSignal.timeout(timeout)
    const response = await send(url, { headers: { Accept: "application/json" }, credentials: "same-origin", signal })
    return response.ok ? facesFrom(await response.json()) : {}
  } catch {
    return {}
  }
}

export function withFaces(known: Faces, arrived: Readonly<Record<string, string>>): Faces {
  const entries = Object.entries(arrived)
  if (entries.length === 0) return known
  return new Map([...known, ...entries])
}
