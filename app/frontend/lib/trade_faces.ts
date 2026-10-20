export const PICKER_PAGE = 36

const FACES_TIMEOUT_MS = 10_000
const FACES_CONCURRENCY = 2
const FACES_ATTEMPTS = 3
const FACES_RETRY_DELAY_MS = 2_000

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

export async function fetchFaces({ url, fetch: send = globalThis.fetch, timeout = FACES_TIMEOUT_MS }: FetchFaces): Promise<Record<string, string> | null> {
  try {
    const signal = AbortSignal.timeout(timeout)
    const response = await send(url, { headers: { Accept: "application/json" }, credentials: "same-origin", signal })
    return response.ok ? facesFrom(await response.json()) : null
  } catch {
    return null
  }
}

export function withFaces(known: Faces, arrived: Readonly<Record<string, string>>): Faces {
  const entries = Object.entries(arrived)
  if (entries.length === 0) return known
  return new Map([...known, ...entries])
}

type FaceLoaderOptions = {
  known: Faces
  batch: number
  load: (keys: readonly string[]) => Promise<Record<string, string> | null>
  onFaces: (faces: Faces) => void
  concurrency?: number
  attempts?: number
  retryDelay?: number
  later?: (run: () => void, delay: number) => void
}

export type FaceLoader = { request: (keys: readonly string[]) => void }

export function faceLoader({
  known: initial,
  batch,
  load,
  onFaces,
  concurrency = FACES_CONCURRENCY,
  attempts = FACES_ATTEMPTS,
  retryDelay = FACES_RETRY_DELAY_MS,
  later = (run, delay) => void setTimeout(run, delay),
}: FaceLoaderOptions): FaceLoader {
  let known = initial
  const pending = new Set<string>()
  const waiting: { keys: string[]; tried: number }[] = []
  let loading = 0

  const settle = (keys: readonly string[]) => keys.forEach((key) => pending.delete(key))

  const pump = () => {
    while (loading < concurrency && waiting.length > 0) {
      const next = waiting.pop()!
      loading += 1
      void load(next.keys).then((arrived) => {
        loading -= 1
        if (arrived) {
          settle(next.keys)
          known = withFaces(known, arrived)
          onFaces(known)
        } else if (next.tried + 1 < attempts) {
          later(() => {
            waiting.push({ keys: next.keys, tried: next.tried + 1 })
            pump()
          }, retryDelay * (next.tried + 1))
        } else {
          settle(next.keys)
        }
        pump()
      })
    }
  }

  return {
    request(keys) {
      const missing = missingFaces(keys, known, pending)
      missing.forEach((key) => pending.add(key))
      batches(missing, batch).forEach((keys) => waiting.push({ keys, tried: 0 }))
      pump()
    },
  }
}
