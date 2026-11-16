export const LEGACY_SEEN_KEY = "gameble:bell-seen"
export const READ_KEYS_PER_POST = 100

export type BellStorage = Pick<Storage, "getItem" | "removeItem">

export type BellLine = { key: string; path?: string; lasting: boolean; read: boolean }

export function opensTarget(path: string | undefined, pathname: string): boolean {
  return Boolean(path) && path === pathname
}

export function linesSeenHere(lines: BellLine[], pathname: string): string[] {
  return lines.filter((line) => !line.lasting && opensTarget(line.path, pathname)).map((line) => line.key)
}

export function dismissibleKeys(lines: BellLine[]): string[] {
  return lines.filter((line) => !line.lasting).map((line) => line.key)
}

export function hiddenLines(lines: BellLine[], readHere: Set<string>): Set<string> {
  return new Set(lines.filter((line) => !line.lasting && (line.read || readHere.has(line.key))).map((line) => line.key))
}

export function keysToSend(keys: string[], lines: BellLine[], readHere: Set<string>): string[] {
  const readOnServer = new Set(lines.filter((line) => line.read).map((line) => line.key))
  return [...new Set(keys)].filter((key) => key && !readOnServer.has(key) && !readHere.has(key))
}

export function legacyStorageKey(owner: string): string {
  return `${LEGACY_SEEN_KEY}:${owner}`
}

export function takeLegacySeen(storage: BellStorage | null, owner: string): string[] {
  try {
    const raw = storage?.getItem(legacyStorageKey(owner))
    if (raw == null) return []
    storage?.removeItem(legacyStorageKey(owner))
    const stored: unknown = JSON.parse(raw)
    if (!Array.isArray(stored)) return []
    return stored.filter((key): key is string => typeof key === "string" && key !== "").slice(-READ_KEYS_PER_POST)
  } catch {
    return []
  }
}

export function bellStorage(): BellStorage | null {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export type SendRead = {
  url: string
  keys: string[]
  csrfToken: string | null
  fetch?: typeof globalThis.fetch
}

export async function sendRead({ url, keys, csrfToken, fetch: send = globalThis.fetch }: SendRead): Promise<boolean> {
  if (keys.length === 0) return true

  const headers: Record<string, string> = { Accept: "application/json", "Content-Type": "application/json" }
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken
  try {
    const response = await send(url, {
      method: "POST",
      headers,
      credentials: "same-origin",
      keepalive: true,
      body: JSON.stringify({ keys: keys.slice(-READ_KEYS_PER_POST) }),
    })
    return response.ok
  } catch {
    return false
  }
}
