import { describe, expect, it } from "vitest"
import { ArtPrefetch, PREFETCH_CONCURRENCY, heldCapsulesOf, type PrefetchEnvironment } from "./art_prefetch"
import { arming, lock } from "./booster"
import { idle } from "./booster_state"
import { FIVE, answerOf, cardOf, heldOf, startWith } from "./booster_fixtures"
import { IMAGE_REQUEST } from "./card_art/worker_job"
import type { HeldCapsule } from "./opening"

const covered = (token: string, count = 5): HeldCapsule => ({
  ...heldOf(FIVE.slice(0, count), token),
  cards: FIVE.slice(0, count).map((tier, index) => ({
    ...cardOf(tier, `${token}-${index}`),
    coverUrl: `https://cdn/${token}/${index}.jpg`,
  })),
})

type Pending = { url: string; init: RequestInit; settle: (ok: boolean) => void }

function fakeEnvironment({ saveData = false } = {}) {
  const pending: Pending[] = []
  const requested: Pending[] = []
  const idles: (() => void)[] = []
  const environment: PrefetchEnvironment = {
    fetch: (url, init) =>
      new Promise((resolve, reject) => {
        const entry: Pending = {
          url,
          init,
          settle: (ok) => (ok ? resolve({ blob: () => Promise.resolve(new Blob()) }) : reject(new TypeError("cors"))),
        }
        pending.push(entry)
        requested.push(entry)
      }),
    saveData: () => saveData,
    idle: (run) => {
      idles.push(run)
      return () => idles.splice(idles.indexOf(run), 1)
    },
  }
  const runIdle = (): void => idles.splice(0).forEach((run) => run())
  const settleAll = async (ok = true): Promise<void> => {
    pending.splice(0).forEach((entry) => entry.settle(ok))
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
  return { environment, requested, pending, idles, runIdle, settleAll }
}

function prefetchOf(capsules: () => readonly HeldCapsule[], calm: () => boolean = () => true, saveData = false) {
  const fake = fakeEnvironment({ saveData })
  return { ...fake, prefetch: new ArtPrefetch({ capsules, calm }, fake.environment) }
}

describe("ArtPrefetch", () => {
  it("requests each cover of a held capsule once with the art worker's request, a few at a time", async () => {
    const { prefetch, requested, runIdle, settleAll } = prefetchOf(() => [covered("t1")])
    prefetch.consider()
    expect(requested).toHaveLength(0)
    runIdle()
    expect(requested).toHaveLength(PREFETCH_CONCURRENCY)
    await settleAll()
    runIdle()
    await settleAll()
    expect(requested.map((entry) => entry.url)).toEqual([0, 1, 2, 3, 4].map((index) => `https://cdn/t1/${index}.jpg`))
    requested.forEach(({ init }) => expect(init).toMatchObject(IMAGE_REQUEST))
    requested.forEach(({ init }) => expect(init.signal).toBeInstanceOf(AbortSignal))
  })

  it("never asks again for a token it already prepared", async () => {
    const { prefetch, requested, runIdle, settleAll } = prefetchOf(() => [covered("t1", 2)])
    prefetch.consider()
    runIdle()
    await settleAll()
    prefetch.consider()
    prefetch.consider()
    runIdle()
    expect(requested).toHaveLength(2)
  })

  it("prepares every capsule it is given and a new token when the held capsule changes", async () => {
    let capsules = [covered("standard", 1), covered("special", 1)]
    const { prefetch, requested, runIdle, settleAll } = prefetchOf(() => capsules)
    prefetch.consider()
    runIdle()
    await settleAll()
    capsules = [covered("next", 1), covered("special", 1)]
    prefetch.consider()
    runIdle()
    expect(requested.map((entry) => entry.url)).toEqual([
      "https://cdn/standard/0.jpg",
      "https://cdn/special/0.jpg",
      "https://cdn/next/0.jpg",
    ])
  })

  it("waits while an opening runs and starts once it is calm again", () => {
    let calm = false
    const { prefetch, requested, runIdle } = prefetchOf(
      () => [covered("t1", 2)],
      () => calm,
    )
    prefetch.consider()
    runIdle()
    expect(requested).toHaveLength(0)
    calm = true
    prefetch.consider()
    runIdle()
    expect(requested).toHaveLength(2)
  })

  it("fetches nothing under data saver", () => {
    const { prefetch, requested, idles } = prefetchOf(
      () => [covered("t1")],
      () => true,
      true,
    )
    prefetch.consider()
    expect(idles).toHaveLength(0)
    expect(requested).toHaveLength(0)
  })

  it("ignores a failed fetch and moves on to the next cover", async () => {
    const { prefetch, requested, runIdle, settleAll } = prefetchOf(() => [covered("t1", 4)])
    prefetch.consider()
    runIdle()
    await settleAll(false)
    runIdle()
    expect(requested).toHaveLength(4)
  })

  it("aborts pending fetches and schedules nothing more once stopped", () => {
    const { prefetch, requested, runIdle, idles } = prefetchOf(() => [covered("t1")])
    prefetch.consider()
    runIdle()
    prefetch.stop()
    expect(requested.every(({ init }) => init.signal?.aborted)).toBe(true)
    prefetch.consider()
    expect(idles).toHaveLength(0)
  })

  it("skips cards without a cover", () => {
    const capsule = { ...covered("t1", 2), cards: [cardOf("common")] }
    const { prefetch, requested, idles, runIdle } = prefetchOf(() => [capsule])
    prefetch.consider()
    runIdle()
    expect(idles).toHaveLength(0)
    expect(requested).toHaveLength(0)
  })
})

describe("heldCapsulesOf", () => {
  it("lists both reserves' held capsules and the answer's next", () => {
    const standard = heldOf(FIVE, "standard")
    const special = heldOf(FIVE, "special")
    const next = heldOf(FIVE, "next")
    const state = { ...startWith({ held: { standard, special } }), answer: { ...answerOf(FIVE), next } }
    expect(heldCapsulesOf(state).map((capsule) => capsule.pack.token)).toEqual(["standard", "special", "next"])
    expect(heldCapsulesOf(startWith())).toEqual([])
  })
})

describe("the booster's idle state, which holds prefetches back", () => {
  it("is calm only with no lock, no opening and no reveal-all running", () => {
    expect(idle(startWith())).toBe(true)
    expect(idle(lock(startWith()))).toBe(false)
    expect(idle(arming(startWith(), "key"))).toBe(false)
    expect(idle({ ...startWith(), revealingAll: true })).toBe(false)
  })
})
