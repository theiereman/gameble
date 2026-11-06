// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from "vitest"
import type { BoosterState } from "./booster"
import { answerOf, dealt, revealedAll, startWith } from "./booster_fixtures"
import type { Transition } from "./booster_host"
import { OpeningSequence } from "./booster_opening_sequence"
import { onGameble } from "./events"
import { dealOrder } from "./booster_motion"
import { sendOpening, type OpeningResult } from "./opening"
import type { ScreenTimers } from "./screen_timers"

vi.mock("./opening", async (original) => ({ ...(await original<typeof import("./opening")>()), sendOpening: vi.fn() }))
vi.mock("./booster_page", async (original) => ({
  ...(await original<typeof import("./booster_page")>()),
  rememberPack: vi.fn(),
  csrfToken: () => null,
}))

const OPENED: OpeningResult = { kind: "opened", answer: answerOf(["common", "rare", "epic"]) }

type Timers = ScreenTimers & { waits: number[]; flush: () => void; laters: Array<{ ms: number; action: () => void }> }

function heldTimers(): Timers {
  const resolvers: Array<() => void> = []
  const waits: number[] = []
  const laters: Array<{ ms: number; action: () => void }> = []
  return {
    disposed: false,
    waits,
    laters,
    wait: (ms) => {
      waits.push(ms)
      return new Promise<void>((resolve) => resolvers.push(resolve))
    },
    later: (ms, action) => laters.push({ ms, action }),
    dispose: () => {},
    flush: () => resolvers.splice(0).forEach((resolve) => resolve()),
  }
}

function sequenceFrom(initial: BoosterState, timers: Timers) {
  let state = initial
  const finish = vi.fn()
  const animation = { finish, effect: { getComputedTiming: () => ({ endTime: 300 }) } }
  const endless = { finish: vi.fn(), effect: { getComputedTiming: () => ({ endTime: Infinity }) } }
  const root = { getAnimations: () => [animation, endless] } as unknown as HTMLElement
  const sequence = new OpeningSequence({
    root,
    current: () => state,
    timers: () => timers,
    apply: (transition: Transition) => (state = transition(state)),
    announce: () => {},
    part: () => null,
    slot: () => null,
    traySlot: () => null,
    shake: () => null,
    fx: () => null,
    flash: () => null,
    canister: () => null,
    phoneLayout: () => false,
    openUrl: "/en/packs",
    reserve: () => state.reserve,
    failedMessage: "failed",
    refusedTitle: "refused",
    keepFaces: () => {},
    refreshBank: async () => {},
  })
  return { sequence, state: () => state, finish, endless }
}

const settled = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("OpeningSequence", () => {
  beforeEach(() => {
    vi.mocked(sendOpening).mockReset()
    vi.mocked(sendOpening).mockResolvedValue(OPENED)
  })

  it("sends the next opening while the hand on the table still sinks away", async () => {
    const timers = heldTimers()
    const { sequence, state } = sequenceFrom(revealedAll(dealt()), timers)

    void sequence.open()
    await settled()

    expect(sendOpening).toHaveBeenCalledOnce()
    expect(state()).toMatchObject({ phase: "dealt", headShown: false })
    expect(state().answer).not.toBeNull()
    expect(timers.waits).toHaveLength(1)
  })

  it("deals the cards at once when skipped, finishing the animations that can end", async () => {
    const timers = heldTimers()
    const { sequence, state, finish, endless } = sequenceFrom(startWith(), timers)

    const opened = sequence.open()
    await settled()
    expect(state().phase).toBe("opening")

    sequence.skip()
    await opened

    expect(state()).toMatchObject({ phase: "dealt", opening: false, focus: "card", lockDepth: 0 })
    expect(state().answer?.cards).toHaveLength(3)
    expect(finish).toHaveBeenCalled()
    expect(endless.finish).not.toHaveBeenCalled()
  })

  it("waits out every pause when nobody skips", async () => {
    const timers = heldTimers()
    const { sequence, state, finish } = sequenceFrom(startWith(), timers)

    const opened = sequence.open()
    await settled()
    timers.flush()
    await settled()
    timers.flush()
    await settled()
    timers.flush()
    await opened

    expect(state().phase).toBe("dealt")
    expect(timers.waits.length).toBeGreaterThanOrEqual(3)
    expect(finish).not.toHaveBeenCalled()
  })

  it("ignores a skip pressed before the capsule opens", async () => {
    const timers = heldTimers()
    const { sequence, state } = sequenceFrom(startWith(), timers)

    sequence.skip()
    const opened = sequence.open()
    await settled()

    expect(state().phase).toBe("opening")
    timers.flush()
    await settled()
    expect(state().status).toBe("ejecting")
    sequence.skip()
    await opened
    expect(state().phase).toBe("dealt")
  })

  it("taps once on the touch, then once per card as the cards leave the capsule in cascade", async () => {
    const timers = heldTimers()
    const { sequence } = sequenceFrom(startWith(), timers)
    const taps: string[] = []
    const stops = [
      onGameble("gameble:capsule-touched", () => taps.push("touch")),
      onGameble("gameble:card-dealt", ({ index }) => taps.push(`card ${index}`)),
    ]

    const opened = sequence.open()
    await settled()
    timers.flush()
    await settled()
    timers.flush()
    await settled()
    ;[...timers.laters].sort((a, b) => a.ms - b.ms).forEach(({ action }) => action())
    timers.flush()
    await opened
    stops.forEach((stop) => stop())

    expect(taps).toEqual(["touch", ...dealOrder(3).map((index) => `card ${index}`)])
  })

  it("stops the remaining card taps once the deal is skipped", async () => {
    const timers = heldTimers()
    const { sequence } = sequenceFrom(startWith(), timers)
    const taps: number[] = []
    const stop = onGameble("gameble:card-dealt", ({ index }) => taps.push(index))

    const opened = sequence.open()
    await settled()
    timers.flush()
    await settled()
    timers.flush()
    await settled()
    sequence.skip()
    await opened
    timers.laters.forEach(({ action }) => action())
    stop()

    expect(taps).toEqual([])
  })
})
