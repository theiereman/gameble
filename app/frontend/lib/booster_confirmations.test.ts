// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  arming,
  cardsDealt,
  heldEntry,
  heldOpened,
  lock,
  openingEnded,
  openingStarted,
  resultHeadShown,
  revealMarked,
  unlock,
  type BoosterState,
} from "./booster"
import { OpeningConfirmations } from "./booster_confirmations"
import { FIVE, bank, cardOf, confirmationOf, heldOf, startWith } from "./booster_fixtures"
import type { Transition } from "./booster_host"
import { reflectChange } from "./booster_reflect"
import { onGameble } from "./events"
import { sendOpening, type OpeningResult } from "./opening"
import { QUEUE_STORAGE_KEY, loadOpened, loadQueue } from "./opening_queue"
import { sendReveal } from "./reveal"
import type { ScreenTimers } from "./screen_timers"

vi.mock("./opening", async (original) => ({ ...(await original<typeof import("./opening")>()), sendOpening: vi.fn() }))
vi.mock("./reveal", () => ({ sendReveal: vi.fn(async () => {}) }))
vi.mock("./booster_page", async (original) => ({
  ...(await original<typeof import("./booster_page")>()),
  csrfToken: () => null,
}))

const HELD = heldOf(FIVE, "held-1")
const NEXT = heldOf(["rare", "rare", "rare"], "held-2")

function dealtHeld(): BoosterState {
  const armed = arming(
    lock(openingStarted(startWith({ bank: bank(2), held: { standard: HELD, special: null } }))),
    null,
  )
  return unlock(openingEnded(cardsDealt(resultHeadShown(heldOpened(armed, heldEntry(armed, "key-1")!)))))
}

function confirmationsFrom(initial: BoosterState) {
  let state = initial
  const laters: Array<() => void> = []
  const timers: ScreenTimers = {
    disposed: false,
    wait: () => new Promise(() => {}),
    later: (_, action) => laters.push(action),
    dispose: () => {},
  }
  const host = {
    openUrl: "/en/packs",
    current: () => state,
    timers: () => timers,
    apply: (transition: Transition) => (state = transition(state)),
    announce: vi.fn(),
    keepFaces: vi.fn(),
    refreshBank: vi.fn(async () => {}),
  }
  const confirmations = new OpeningConfirmations(host)
  return { confirmations, host, laters, state: () => state }
}

const settled = () => new Promise((resolve) => setTimeout(resolve, 0))

describe("OpeningConfirmations", () => {
  beforeEach(() => {
    localStorage.clear()
    vi.mocked(sendOpening).mockReset()
  })

  afterEach(() => localStorage.clear())

  it("sends the opening once, naming the capsule's token with its key, and adopts the server's answer", async () => {
    vi.mocked(sendOpening).mockResolvedValue({ kind: "opened", answer: confirmationOf(HELD, { next: NEXT }) })
    const { confirmations, host, state } = confirmationsFrom(dealtHeld())
    const changed = vi.fn()
    const stop = onGameble("gameble:booster-changed", changed)

    confirmations.confirm(state().confirming[0])
    expect(loadQueue()).toEqual([{ token: "held-1", key: "key-1", reserve: "standard" }])
    await settled()
    stop()
    expect(changed).toHaveBeenCalledOnce()

    expect(sendOpening).toHaveBeenCalledOnce()
    expect(sendOpening).toHaveBeenCalledWith(
      expect.objectContaining({ url: "/en/packs", pack: "held-1", key: "key-1", reserve: "standard" }),
    )
    expect(state()).toMatchObject({ provisional: false, confirming: [] })
    expect(state().held.standard).toBe(NEXT)
    expect(host.keepFaces).not.toHaveBeenCalled()
    expect(localStorage.getItem(QUEUE_STORAGE_KEY)).toBeNull()
    expect(loadOpened()).toEqual(["held-1"])
  })

  it("gives the hand the server's faces when the server answers other cards", async () => {
    const other = confirmationOf({ ...HELD, cards: [cardOf("legendary", "other"), ...HELD.cards.slice(1)] })
    vi.mocked(sendOpening).mockResolvedValue({ kind: "opened", answer: other })
    const { confirmations, host, state } = confirmationsFrom(dealtHeld())

    confirmations.confirm(state().confirming[0])
    await settled()

    expect(host.keepFaces).toHaveBeenCalledWith(other)
    expect(state().answer).toBe(other)
  })

  it("keeps the opening through a lost connection and sends it again when the browser is back online, then when visible", async () => {
    vi.mocked(sendOpening).mockResolvedValue({ kind: "failed" })
    const { confirmations, state } = confirmationsFrom(dealtHeld())
    const toasts: unknown[] = []
    const stop = onGameble("gameble:toast", (detail) => toasts.push(detail))
    confirmations.start()
    await settled()
    expect(sendOpening).toHaveBeenCalledTimes(1)
    expect(state().confirming).toHaveLength(1)

    window.dispatchEvent(new Event("online"))
    await settled()
    expect(sendOpening).toHaveBeenCalledTimes(2)

    vi.mocked(sendOpening).mockResolvedValue({ kind: "opened", answer: confirmationOf(HELD) })
    Object.defineProperty(document, "visibilityState", { value: "visible", configurable: true })
    document.dispatchEvent(new Event("visibilitychange"))
    await settled()
    confirmations.stop()
    stop()

    expect(sendOpening).toHaveBeenCalledTimes(3)
    expect(new Set(vi.mocked(sendOpening).mock.calls.map(([call]) => call.key))).toEqual(new Set(["key-1"]))
    expect(state().confirming).toEqual([])
    expect(toasts).toEqual([])
  })

  it("retries after a backoff while the screen is open", async () => {
    vi.mocked(sendOpening).mockResolvedValue({ kind: "failed" })
    const { confirmations, laters } = confirmationsFrom(dealtHeld())
    confirmations.start()
    await settled()
    expect(laters).toHaveLength(1)

    laters[0]()
    await settled()
    confirmations.stop()
    expect(sendOpening).toHaveBeenCalledTimes(2)
  })

  it("drops a refused opening, says why politely and refreshes the bank, with no toast", async () => {
    const refusal: OpeningResult = { kind: "refused", code: "pack_not_available", message: "Gone." }
    vi.mocked(sendOpening).mockResolvedValue(refusal)
    const { confirmations, host, state } = confirmationsFrom(dealtHeld())
    const toasts: unknown[] = []
    const stop = onGameble("gameble:toast", (detail) => toasts.push(detail))

    confirmations.confirm(state().confirming[0])
    await settled()
    stop()

    expect(state().confirming).toEqual([])
    expect(host.announce).toHaveBeenCalledWith("Gone.")
    expect(host.refreshBank).toHaveBeenCalledOnce()
    expect(toasts).toEqual([])
    expect(loadQueue()).toEqual([])
    expect(loadOpened()).toEqual([])
  })
})

describe("the reveal mode of a held capsule", () => {
  beforeEach(() => {
    vi.mocked(sendReveal).mockClear()
    vi.stubGlobal("Turbo", { cache: { clear: () => {} } })
  })

  afterEach(() => vi.unstubAllGlobals())

  it("is sent once its confirmation lands, not before", async () => {
    vi.mocked(sendOpening).mockResolvedValue({ kind: "opened", answer: confirmationOf(HELD) })
    const hand = dealtHeld()
    const done = hand.revealed.reduce((next, _, index) => revealMarked(next, index, 0), hand)
    reflectChange(hand, done, undefined, "", () => {})
    expect(sendReveal).not.toHaveBeenCalled()

    const { confirmations, state } = confirmationsFrom(done)
    confirmations.confirm(done.confirming[0])
    await settled()
    reflectChange(done, state(), undefined, "", () => {})
    reflectChange(state(), state(), undefined, "", () => {})

    expect(sendReveal).toHaveBeenCalledOnce()
    expect(sendReveal).toHaveBeenCalledWith({
      url: "/pack/held-1/reveal",
      mode: "one_by_one",
      timings: {},
      csrfToken: null,
    })
  })
})
