// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from "vitest"
import type { BoosterState } from "./booster"
import { openingConfirmed } from "./booster"
import { FIVE, answerOf, bank, confirmationOf, dealt, heldOf, revealedAll, startWith } from "./booster_fixtures"
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

type Confirming = { landed?: Promise<boolean> }

function sequenceFrom(initial: BoosterState, timers: Timers, confirming: Confirming = {}) {
  let state = initial
  const confirm = vi.fn()
  const awaitConfirmation = vi.fn(() => confirming.landed ?? Promise.resolve(true))
  const announce = vi.fn()
  const finish = vi.fn()
  const animation = { finish, effect: { getComputedTiming: () => ({ endTime: 300 }) } }
  const endless = { finish: vi.fn(), effect: { getComputedTiming: () => ({ endTime: Infinity }) } }
  const root = { getAnimations: () => [animation, endless] } as unknown as HTMLElement
  const sequence = new OpeningSequence({
    root,
    current: () => state,
    timers: () => timers,
    apply: (transition: Transition) => (state = transition(state)),
    announce,
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
    confirm,
    awaitConfirmation,
  })
  const apply = (transition: Transition) => (state = transition(state))
  return { sequence, state: () => state, apply, finish, endless, confirm, awaitConfirmation, announce }
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

describe("OpeningSequence with a held capsule", () => {
  const HELD = heldOf(FIVE, "held-1")
  const NEXT = heldOf(["rare", "rare", "rare"], "held-2")
  const withHeld = () => startWith({ bank: bank(2), held: { standard: HELD, special: null } })
  const pendingOnly = () =>
    startWith({ bank: bank(2), confirming: [{ token: "held-0", key: "k0", reserve: "standard" }] })

  beforeEach(() => {
    vi.mocked(sendOpening).mockReset()
    vi.mocked(sendOpening).mockResolvedValue({ kind: "failed" })
  })

  function toasts() {
    const shown: Array<{ title?: string; message: string }> = []
    const stop = onGameble("gameble:toast", (detail) => shown.push(detail))
    return { shown, stop }
  }

  it("blasts and deals its cards with no network wait, and queues its confirmation once", async () => {
    const timers = heldTimers()
    const { sequence, state, confirm, awaitConfirmation } = sequenceFrom(withHeld(), timers)
    const { shown, stop } = toasts()

    const opened = sequence.open()
    await settled()
    timers.flush()
    await settled()

    expect(state().status).toBe("ejecting")
    expect(state().answer?.cards).toBe(HELD.cards)
    expect(state().provisional).toBe(true)
    expect(confirm).toHaveBeenCalledOnce()
    expect(confirm).toHaveBeenCalledWith({ token: "held-1", key: expect.any(String), reserve: "standard" })
    expect(sendOpening).not.toHaveBeenCalled()
    expect(awaitConfirmation).not.toHaveBeenCalled()

    sequence.skip()
    await opened
    stop()
    expect(state()).toMatchObject({ phase: "dealt", opening: false, lockDepth: 0 })
    expect(shown).toEqual([])
  })

  it("waits for a reserve's pending confirmation, then opens the capsule it names next, never sending a token-less opening", async () => {
    const timers = heldTimers()
    let land: (landed: boolean) => void = () => {}
    const landed = new Promise<boolean>((resolve) => (land = resolve))
    const { sequence, state, apply, confirm, awaitConfirmation } = sequenceFrom(pendingOnly(), timers, { landed })

    const opened = sequence.open()
    await settled()
    timers.flush()
    await settled()
    expect(awaitConfirmation).toHaveBeenCalledWith("standard")
    expect(state().status).toBe("arming")

    apply((s) => openingConfirmed(s, "held-0", confirmationOf(heldOf(FIVE, "held-0"), { available: 2, next: NEXT })))
    land(true)
    await settled()
    sequence.skip()
    await opened

    expect(state().answer?.pack.token).toBe("held-2")
    expect(confirm).toHaveBeenCalledWith({ token: "held-2", key: expect.any(String), reserve: "standard" })
    expect(sendOpening).not.toHaveBeenCalled()
  })

  it("rests the capsule with the no-connection copy, no cancellation title, when the pending confirmation cannot land", async () => {
    const timers = heldTimers()
    const { sequence, state, announce } = sequenceFrom(pendingOnly(), timers, { landed: Promise.resolve(false) })
    const { shown, stop } = toasts()

    const opened = sequence.open()
    await settled()
    timers.flush()
    await opened
    stop()

    expect(state()).toMatchObject({ phase: "sealed", opening: false, reason: "failed", lockDepth: 0 })
    expect(announce).toHaveBeenCalledWith("failed")
    expect(shown).toEqual([{ message: "failed", tone: "alert" }])
    expect(sendOpening).not.toHaveBeenCalled()
  })
})

describe("OpeningSequence with no held capsule", () => {
  beforeEach(() => vi.mocked(sendOpening).mockReset())

  async function openedWith(result: OpeningResult) {
    vi.mocked(sendOpening).mockResolvedValue(result)
    const timers = heldTimers()
    const { sequence, state } = sequenceFrom(startWith(), timers)
    const shown: Array<{ title?: string; message: string }> = []
    const stop = onGameble("gameble:toast", (detail) => shown.push(detail))
    const opened = sequence.open()
    await settled()
    timers.flush()
    await opened
    stop()
    return { state, shown }
  }

  it("says a lost answer without the cancellation title", async () => {
    const { state, shown } = await openedWith({ kind: "failed" })
    expect(sendOpening).toHaveBeenCalledWith(expect.not.objectContaining({ pack: expect.anything() }))
    expect(state().reason).toBe("failed")
    expect(shown).toEqual([{ message: "failed", tone: "alert" }])
  })

  it("keeps the cancellation title for a refusal", async () => {
    const { shown } = await openedWith({ kind: "refused", code: "no_pack_available", message: "None left." })
    expect(shown).toEqual([{ title: "refused", message: "None left.", tone: "alert" }])
  })
})
