export const BELL_SEEN_KEY = "gameble:bell-seen"
export const BELL_SEEN_CAP = 100

export type BellStorage = Pick<Storage, "getItem" | "setItem">

export function seenStorageKey(owner: string): string {
  return `${BELL_SEEN_KEY}:${owner}`
}

export function readSeen(storage: BellStorage | null, owner: string): Set<string> {
  try {
    const stored: unknown = JSON.parse(storage?.getItem(seenStorageKey(owner)) ?? "[]")
    return new Set(Array.isArray(stored) ? stored.filter((key): key is string => typeof key === "string") : [])
  } catch {
    return new Set()
  }
}

export function markSeen(keys: string[], storage: BellStorage | null, owner: string): void {
  const fresh = keys.filter(Boolean)
  if (fresh.length === 0) return

  const kept = [...readSeen(storage, owner)].filter((key) => !fresh.includes(key))
  try {
    storage?.setItem(seenStorageKey(owner), JSON.stringify([...kept, ...fresh].slice(-BELL_SEEN_CAP)))
  } catch {
    // Refused (private mode, quota): nothing is remembered, every line stays.
  }
}

export function opensTarget(path: string | undefined, pathname: string): boolean {
  return Boolean(path) && path === pathname
}

export type BellLine = { key: string; path?: string; lasting: boolean }

export function linesSeenHere(lines: BellLine[], pathname: string): string[] {
  return lines.filter((line) => !line.lasting && opensTarget(line.path, pathname)).map((line) => line.key)
}

export function dismissibleKeys(lines: BellLine[]): string[] {
  return lines.filter((line) => !line.lasting).map((line) => line.key)
}

export function hiddenLines(lines: BellLine[], seen: Set<string>): Set<string> {
  return new Set(lines.filter((line) => !line.lasting && seen.has(line.key)).map((line) => line.key))
}

export function bellStorage(): BellStorage | null {
  try {
    return window.localStorage
  } catch {
    return null
  }
}
