import { describe, expect, it, vi } from "vitest"
import { answerOf } from "./booster_fixtures"
import type { OpeningResult } from "./opening"
import {
  OpeningQueue,
  OPENED_REMEMBERED,
  OPENED_STORAGE_KEY,
  QUEUE_STORAGE_KEY,
  RETRY_DELAYS,
  SEND_TIMEOUT_MS,
  dequeueStored,
  enqueueStored,
  loadOpened,
  loadQueue,
  rememberOpened,
  retryDelay,
  settledOpening,
  withQueued,
  type QueueStorage,
  type QueuedOpening,
  type SettledOpening,
} from "./opening_queue"
import type { ScreenTimers } from "./screen_timers"

const ENTRY: QueuedOpening = { token: "t1", key: "k1", reserve: "standard" }
const SPECIAL: QueuedOpening = { token: "t2", key: "k2", reserve: "special" }
const OPENED: OpeningResult = { kind: "opened", answer: answerOf(["common"]) }

function memoryStorage(initial: Record<string, string> = {}): QueueStorage & { items: Record<string, string> } {
  const items = { ...initial }
  return {
    items,
    getItem: (key) => items[key] ?? null,
    setItem: (key, value) => void (items[key] = value),
    removeItem: (key) => void delete items[key],
  }
}

const brokenStorage: QueueStorage = {
  getItem: () => {
    throw new Error("SecurityError")
  },
  setItem: () => {
    throw new Error("QuotaExceededError")
  },
  removeItem: () => {
    throw new Error("SecurityError")
  },
}

describe("the stored queue", () => {
  it("keeps each pending opening's token, key and reserve across reloads", () => {
    const storage = memoryStorage()
    enqueueStored(ENTRY, storage)
    enqueueStored(SPECIAL, storage)
    expect(loadQueue(storage)).toEqual([ENTRY, SPECIAL])

    dequeueStored("t1", storage)
    expect(loadQueue(storage)).toEqual([SPECIAL])
    dequeueStored("t2", storage)
    expect(storage.items[QUEUE_STORAGE_KEY]).toBeUndefined()
  })

  it("never queues a token again with a new key", () => {
    const storage = memoryStorage()
    enqueueStored(ENTRY, storage)
    enqueueStored({ ...ENTRY, key: "k-new" }, storage)
    expect(loadQueue(storage)).toEqual([ENTRY])
    expect(withQueued([ENTRY], { ...ENTRY, key: "k-new" })).toEqual([ENTRY])
  })

  it("works without storage, blocked storage or a stored value of another shape", () => {
    expect(loadQueue(null)).toEqual([])
    expect(loadQueue(brokenStorage)).toEqual([])
    expect(() => enqueueStored(ENTRY, brokenStorage)).not.toThrow()
    expect(() => dequeueStored("t1", brokenStorage)).not.toThrow()
    expect(loadQueue(memoryStorage({ [QUEUE_STORAGE_KEY]: "{oops" }))).toEqual([])
    expect(loadQueue(memoryStorage({ [QUEUE_STORAGE_KEY]: '{"token":"t"}' }))).toEqual([])
    const mixed = JSON.stringify([ENTRY, { token: "t", key: "k", reserve: "gold" }, { token: "", key: "k" }])
    expect(loadQueue(memoryStorage({ [QUEUE_STORAGE_KEY]: mixed }))).toEqual([ENTRY])
  })
})

describe("the opened capsules remembered", () => {
  it("keeps the latest confirmed tokens once each, so a stored page never reopens one", () => {
    const storage = memoryStorage()
    rememberOpened("t1", storage)
    rememberOpened("t2", storage)
    rememberOpened("t1", storage)
    expect(loadOpened(storage)).toEqual(["t2", "t1"])

    for (let index = 0; index < OPENED_REMEMBERED; index++) rememberOpened(`n${index}`, storage)
    expect(loadOpened(storage)).toHaveLength(OPENED_REMEMBERED)
    expect(loadOpened(storage)).not.toContain("t1")
  })

  it("works without storage, blocked storage or a stored value of another shape", () => {
    expect(loadOpened(null)).toEqual([])
    expect(loadOpened(brokenStorage)).toEqual([])
    expect(() => rememberOpened("t1", brokenStorage)).not.toThrow()
    expect(loadOpened(memoryStorage({ [OPENED_STORAGE_KEY]: "{oops" }))).toEqual([])
    expect(loadOpened(memoryStorage({ [OPENED_STORAGE_KEY]: '["t1", 2, ""]' }))).toEqual(["t1"])
  })
})

describe("settledOpening", () => {
  it("settles an opening on a server answer, keeps it on a lost answer or a throttle", () => {
    expect(settledOpening(OPENED)).toBe(OPENED)
    const refused: OpeningResult = { kind: "refused", code: "pack_not_available", message: "Gone." }
    expect(settledOpening(refused)).toBe(refused)
    expect(settledOpening({ kind: "failed" })).toBeNull()
    expect(settledOpening({ kind: "refused", code: "throttled", message: "Slow down." })).toBeNull()
  })

  it("waits longer after each failure, up to a ceiling", () => {
    expect(RETRY_DELAYS.map((_, attempt) => retryDelay(attempt))).toEqual([...RETRY_DELAYS])
    expect(retryDelay(99)).toBe(RETRY_DELAYS.at(-1))
  })
})

type Laters = ScreenTimers & { laters: Array<{ ms: number; action: () => void }> }

function fakeTimers(): Laters {
  const laters: Array<{ ms: number; action: () => void }> = []
  return {
    disposed: false,
    laters,
    wait: () => new Promise(() => {}),
    later: (ms, action) => laters.push({ ms, action }),
    dispose: () => {},
  }
}

function queueOf(results: OpeningResult[], initial: QueuedOpening[] = [ENTRY]) {
  let entries = [...initial]
  const timers = fakeTimers()
  const send = vi.fn(
    async (_entry: QueuedOpening, _signal: AbortSignal): Promise<OpeningResult> =>
      results.shift() ?? { kind: "failed" },
  )
  const settled: Array<[QueuedOpening, SettledOpening]> = []
  const queue = new OpeningQueue({
    entries: () => entries,
    send,
    settle: (entry, result) => {
      settled.push([entry, result])
      entries = entries.filter(({ token }) => token !== entry.token)
    },
    timers: () => timers,
  })
  return { queue, send, settled, timers, entries: () => entries }
}

const flushed = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("OpeningQueue", () => {
  it("sends each pending opening once, however often it is flushed while the answer is on its way", async () => {
    const { queue, send, settled } = queueOf([OPENED])
    queue.flush()
    queue.flush()
    await flushed()
    expect(send).toHaveBeenCalledOnce()
    expect(send).toHaveBeenCalledWith(ENTRY, expect.any(AbortSignal))
    expect(settled).toEqual([[ENTRY, OPENED]])
  })

  it("keeps an opening whose answer is lost and sends it again, with the same key, after a backoff", async () => {
    const { queue, send, settled, timers, entries } = queueOf([{ kind: "failed" }, OPENED])
    queue.flush()
    await flushed()
    expect(settled).toEqual([])
    expect(entries()).toEqual([ENTRY])
    expect(timers.laters.map(({ ms }) => ms)).toEqual([RETRY_DELAYS[0]])

    timers.laters[0].action()
    await flushed()
    expect(send).toHaveBeenCalledTimes(2)
    expect(send.mock.calls[1][0]).toEqual(ENTRY)
    expect(settled).toEqual([[ENTRY, OPENED]])
  })

  it("plans one retry at a time, each further than the last", async () => {
    const { queue, timers } = queueOf([{ kind: "failed" }, { kind: "failed" }], [ENTRY, SPECIAL])
    queue.flush()
    await flushed()
    expect(timers.laters).toHaveLength(1)
    timers.laters[0].action()
    await flushed()
    expect(timers.laters.map(({ ms }) => ms)).toEqual([RETRY_DELAYS[0], RETRY_DELAYS[1]])
  })

  it("plans no retry once the screen is gone", async () => {
    const { queue, timers } = queueOf([{ kind: "failed" }])
    Object.defineProperty(timers, "disposed", { value: true })
    queue.flush()
    await flushed()
    expect(timers.laters).toEqual([])
  })

  it("gives each send a signal that aborts a hanging request", async () => {
    const { queue, send } = queueOf([OPENED])
    queue.flush()
    await flushed()
    const signal = (send.mock.calls[0] as unknown as [QueuedOpening, AbortSignal])[1]
    expect(signal).toBeInstanceOf(AbortSignal)
    expect(signal.aborted).toBe(false)
  })

  it("keeps an opening whose send is aborted and sends it again on the next flush", async () => {
    const { queue, send, settled, entries } = queueOf([])
    send.mockImplementationOnce(
      (_entry: QueuedOpening, signal: AbortSignal) =>
        new Promise<OpeningResult>((_, reject) => signal.addEventListener("abort", () => reject(new Error("aborted")))),
    )
    const timeout = new AbortController()
    const asked = vi.spyOn(AbortSignal, "timeout").mockReturnValue(timeout.signal)
    queue.flush()
    expect(asked).toHaveBeenCalledWith(SEND_TIMEOUT_MS)
    asked.mockRestore()
    timeout.abort()
    await flushed()
    expect(settled).toEqual([])
    expect(entries()).toEqual([ENTRY])
    queue.flush()
    expect(send).toHaveBeenCalledTimes(2)
  })

  it("tells whether a reserve's pending openings landed", async () => {
    const landed = queueOf([OPENED], [ENTRY])
    expect(await landed.queue.settled("standard")).toBe(true)

    const lost = queueOf([{ kind: "failed" }], [ENTRY])
    expect(await lost.queue.settled("standard")).toBe(false)
    expect(lost.entries()).toEqual([ENTRY])
  })
})
