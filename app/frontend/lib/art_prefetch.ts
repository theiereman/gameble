import { IMAGE_REQUEST } from "./card_art/worker_job"
import type { BoosterState } from "./booster_types"
import type { HeldCapsule } from "./opening"

export const PREFETCH_CONCURRENCY = 3

const IDLE_TIMEOUT_MS = 2_000

const IDLE_FALLBACK_MS = 200

export type PrefetchEnvironment = Readonly<{
  fetch: (url: string, init: RequestInit) => Promise<Pick<Response, "blob">>
  saveData: () => boolean
  idle: (run: () => void) => () => void
}>

export type ArtPrefetchHost = Readonly<{
  capsules: () => readonly HeldCapsule[]
  calm: () => boolean
}>

export function heldCapsulesOf(state: BoosterState): HeldCapsule[] {
  return [state.held.standard, state.held.special, state.answer?.next ?? null].filter(
    (capsule): capsule is HeldCapsule => capsule !== null,
  )
}

type NetworkInformation = { saveData?: boolean }

export function browserPrefetch(): PrefetchEnvironment {
  return {
    fetch: (url, init) => fetch(url, init),
    saveData: () => (navigator as Navigator & { connection?: NetworkInformation }).connection?.saveData === true,
    idle: (run) => {
      if (typeof window.requestIdleCallback === "function") {
        const handle = window.requestIdleCallback(run, { timeout: IDLE_TIMEOUT_MS })
        return () => window.cancelIdleCallback(handle)
      }
      const handle = window.setTimeout(run, IDLE_FALLBACK_MS)
      return () => window.clearTimeout(handle)
    },
  }
}

export class ArtPrefetch {
  readonly #preparedTokens = new Set<string>()
  readonly #requestedUrls = new Set<string>()
  readonly #abort = new AbortController()
  #waiting: string[] = []
  #running = 0
  #cancelIdle: (() => void) | null = null

  constructor(
    private readonly host: ArtPrefetchHost,
    private readonly environment: PrefetchEnvironment = browserPrefetch(),
  ) {}

  consider(): void {
    if (this.#stopped || this.environment.saveData()) return
    for (const capsule of this.host.capsules()) this.#prepare(capsule)
    this.#scheduleDrain()
  }

  stop(): void {
    this.#abort.abort()
    this.#cancelIdle?.()
    this.#cancelIdle = null
    this.#waiting = []
  }

  get #stopped(): boolean {
    return this.#abort.signal.aborted
  }

  #prepare(capsule: HeldCapsule): void {
    if (this.#preparedTokens.has(capsule.pack.token)) return
    this.#preparedTokens.add(capsule.pack.token)
    for (const { coverUrl } of capsule.cards) {
      if (coverUrl === "" || this.#requestedUrls.has(coverUrl)) continue
      this.#requestedUrls.add(coverUrl)
      this.#waiting.push(coverUrl)
    }
  }

  #scheduleDrain(): void {
    if (this.#stopped || this.#cancelIdle || this.#waiting.length === 0) return
    if (this.#running >= PREFETCH_CONCURRENCY) return
    this.#cancelIdle = this.environment.idle(() => {
      this.#cancelIdle = null
      this.#drain()
    })
  }

  #drain(): void {
    if (this.#stopped || !this.host.calm() || this.environment.saveData()) return
    while (this.#running < PREFETCH_CONCURRENCY && this.#waiting.length > 0) {
      void this.#request(this.#waiting.shift()!)
    }
  }

  async #request(url: string): Promise<void> {
    this.#running += 1
    await this.environment
      .fetch(url, { ...IMAGE_REQUEST, signal: this.#abort.signal })
      .then((response) => response.blob())
      .catch(() => null)
    this.#running -= 1
    this.#scheduleDrain()
  }
}
