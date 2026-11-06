import type { Reserve } from "./booster_types"
import type { OpeningResult } from "./opening"
import type { ScreenTimers } from "./screen_timers"

export type QueuedOpening = Readonly<{ token: string; key: string; reserve: Reserve }>

export type SettledOpening = Exclude<OpeningResult, { kind: "failed" }>

export const QUEUE_STORAGE_KEY = "gameble:opening-queue"

export const OPENED_STORAGE_KEY = "gameble:opened-capsules"

export const OPENED_REMEMBERED = 8

export const RETRY_DELAYS = [2000, 5000, 15000, 30000] as const

export const SEND_TIMEOUT_MS = 15000

export function timeoutSignal(ms: number): AbortSignal {
  if (typeof AbortSignal.timeout === "function") return AbortSignal.timeout(ms)
  const controller = new AbortController()
  globalThis.setTimeout(() => controller.abort(), ms)
  return controller.signal
}

export type QueueStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">

function browserStorage(): QueueStorage | null {
  try {
    return globalThis.localStorage ?? null
  } catch {
    return null
  }
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)

const isQueued = (value: unknown): value is QueuedOpening =>
  isRecord(value) &&
  typeof value.token === "string" &&
  value.token !== "" &&
  typeof value.key === "string" &&
  value.key !== "" &&
  (value.reserve === "standard" || value.reserve === "special")

export function loadQueue(storage: QueueStorage | null = browserStorage()): QueuedOpening[] {
  try {
    const stored: unknown = JSON.parse(storage?.getItem(QUEUE_STORAGE_KEY) ?? "[]")
    if (!Array.isArray(stored)) return []
    return stored.filter(isQueued).map(({ token, key, reserve }) => ({ token, key, reserve }))
  } catch {
    return []
  }
}

function saveQueue(entries: readonly QueuedOpening[], storage: QueueStorage | null): void {
  try {
    if (entries.length === 0) storage?.removeItem(QUEUE_STORAGE_KEY)
    else storage?.setItem(QUEUE_STORAGE_KEY, JSON.stringify(entries))
  } catch {
    return
  }
}

export const withQueued = (entries: readonly QueuedOpening[], entry: QueuedOpening): readonly QueuedOpening[] =>
  entries.some(({ token }) => token === entry.token) ? entries : [...entries, entry]

export const withoutQueued = (entries: readonly QueuedOpening[], token: string): readonly QueuedOpening[] =>
  entries.some((entry) => entry.token === token) ? entries.filter((entry) => entry.token !== token) : entries

export function enqueueStored(entry: QueuedOpening, storage: QueueStorage | null = browserStorage()): void {
  const entries = loadQueue(storage)
  const after = withQueued(entries, entry)
  if (after !== entries) saveQueue(after, storage)
}

export function dequeueStored(token: string, storage: QueueStorage | null = browserStorage()): void {
  const entries = loadQueue(storage)
  const after = withoutQueued(entries, token)
  if (after !== entries) saveQueue(after, storage)
}

export function loadOpened(storage: QueueStorage | null = browserStorage()): string[] {
  try {
    const stored: unknown = JSON.parse(storage?.getItem(OPENED_STORAGE_KEY) ?? "[]")
    if (!Array.isArray(stored)) return []
    return stored.filter((token): token is string => typeof token === "string" && token !== "")
  } catch {
    return []
  }
}

export function rememberOpened(token: string, storage: QueueStorage | null = browserStorage()): void {
  const tokens = [...loadOpened(storage).filter((opened) => opened !== token), token].slice(-OPENED_REMEMBERED)
  try {
    storage?.setItem(OPENED_STORAGE_KEY, JSON.stringify(tokens))
  } catch {
    return
  }
}

export function settledOpening(result: OpeningResult): SettledOpening | null {
  if (result.kind === "failed") return null
  if (result.kind === "refused" && result.code === "throttled") return null
  return result
}

export const retryDelay = (attempt: number): number =>
  RETRY_DELAYS[Math.min(Math.max(attempt, 0), RETRY_DELAYS.length - 1)]

export type OpeningQueueHost = Readonly<{
  entries: () => readonly QueuedOpening[]
  send: (entry: QueuedOpening, signal: AbortSignal) => Promise<OpeningResult>
  settle: (entry: QueuedOpening, settled: SettledOpening) => void
  timers: () => ScreenTimers
}>

export class OpeningQueue {
  private readonly sending = new Map<string, Promise<void>>()
  private attempts = 0
  private retryPlanned = false

  constructor(private readonly host: OpeningQueueHost) {}

  flush(): void {
    for (const entry of this.host.entries()) {
      if (!this.sending.has(entry.token)) this.sending.set(entry.token, this.sendOnce(entry))
    }
  }

  async settled(reserve: Reserve): Promise<boolean> {
    this.flush()
    const ofReserve = this.host.entries().filter((entry) => entry.reserve === reserve)
    await Promise.all(ofReserve.map(({ token }) => this.sending.get(token)))
    return !this.host.entries().some((entry) => entry.reserve === reserve)
  }

  private async sendOnce(entry: QueuedOpening): Promise<void> {
    let result: OpeningResult
    try {
      result = await this.host.send(entry, timeoutSignal(SEND_TIMEOUT_MS))
    } catch {
      result = { kind: "failed" }
    }
    this.sending.delete(entry.token)
    const settled = settledOpening(result)
    if (settled === null) {
      this.retryLater()
      return
    }
    this.attempts = 0
    this.host.settle(entry, settled)
  }

  private retryLater(): void {
    const timers = this.host.timers()
    if (this.retryPlanned || timers.disposed) return
    this.retryPlanned = true
    timers.later(retryDelay(this.attempts++), () => {
      this.retryPlanned = false
      this.flush()
    })
  }
}
