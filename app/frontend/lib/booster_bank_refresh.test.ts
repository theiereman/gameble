// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { BoosterState } from "./booster"
import { fetchBank, type BankAnswer } from "./booster_bank"
import { BankRefresh } from "./booster_bank_refresh"
import { bank, dealt, heldOf, startWith } from "./booster_fixtures"
import type { Transition } from "./booster_host"
import { onGameble } from "./events"

vi.mock("./booster_bank", async (original) => ({
  ...(await original<typeof import("./booster_bank")>()),
  fetchBank: vi.fn(),
}))

const HELD = heldOf(["rare", "rare", "rare", "rare", "rare"], "held-next")
const ARRIVED: BankAnswer = { bank: bank(1), held: { standard: HELD, special: null } }

const fetched = vi.mocked(fetchBank)

function refreshFrom(initial: BoosterState) {
  let state = initial
  const host = {
    state: () => state,
    current: () => state,
    bankUrl: "/en/booster.json",
    disposed: () => false,
    apply: (transition: Transition) => (state = transition(state)),
    announce: vi.fn(),
  }
  const refresh = new BankRefresh(host)
  refresh.start()
  return { refresh, host, state: () => state }
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 0))

let visitPage: ReturnType<typeof vi.fn>
let started: BankRefresh[] = []

beforeEach(() => {
  visitPage = vi.fn()
  ;(window as unknown as { Turbo: unknown }).Turbo = { visit: visitPage, cache: { clear: () => {} } }
  fetched.mockReset()
  started = []
})

afterEach(() => started.forEach((refresh) => refresh.stop()))

function screen(initial: BoosterState) {
  const parts = refreshFrom(initial)
  started.push(parts.refresh)
  return parts
}

describe("BankRefresh at zero", () => {
  it("brings the canister to an empty screen from the bank, the held capsule kept, without a page visit", async () => {
    fetched.mockResolvedValue(ARRIVED)
    const { refresh, host, state } = screen(startWith({ bank: bank(0) }))

    refresh.atZero()
    await settle()

    expect(fetched).toHaveBeenCalledWith({ url: "/en/booster.json" })
    expect(state()).toMatchObject({ phase: "sealed", status: "sealed", held: { standard: HELD, special: null } })
    expect(state().bank.available).toBe(1)
    expect(host.announce).toHaveBeenCalledWith("standard")
    expect(visitPage).not.toHaveBeenCalled()
  })

  it("updates the counts of a sealed screen without a page visit, and says the booster changed", async () => {
    fetched.mockResolvedValue({ bank: bank(3), held: null })
    const { refresh, state } = screen(startWith())
    const changed = vi.fn()
    const stop = onGameble("gameble:booster-changed", changed)

    refresh.atZero()
    await settle()
    stop()

    expect(state()).toMatchObject({ phase: "sealed", bank: { available: 3, openable: 3 } })
    expect(visitPage).not.toHaveBeenCalled()
    expect(changed).toHaveBeenCalledOnce()
  })

  it("owes the bank while a hand is not put away", async () => {
    const { refresh, state } = screen(dealt())

    refresh.atZero()
    await settle()

    expect(fetched).not.toHaveBeenCalled()
    expect(state()).toMatchObject({ phase: "dealt", bankOwed: true })
  })
})

describe("BankRefresh after a failed read", () => {
  it("leaves the screen as it is, then reads again once the browser is back online", async () => {
    fetched.mockResolvedValueOnce(null).mockResolvedValueOnce(ARRIVED)
    const initial = startWith({ bank: bank(0) })
    const { refresh, state } = screen(initial)

    const changed = vi.fn()
    const stop = onGameble("gameble:booster-changed", changed)
    refresh.atZero()
    await settle()
    stop()
    expect(state()).toBe(initial)
    expect(changed).not.toHaveBeenCalled()

    window.dispatchEvent(new Event("online"))
    await settle()
    expect(fetched).toHaveBeenCalledTimes(2)
    expect(state()).toMatchObject({ phase: "sealed" })
    expect(visitPage).not.toHaveBeenCalled()
  })

  it("reads again when the document becomes visible", async () => {
    fetched.mockResolvedValueOnce(null).mockResolvedValueOnce(ARRIVED)
    const { refresh, state } = screen(startWith({ bank: bank(0) }))

    refresh.atZero()
    await settle()
    document.dispatchEvent(new Event("visibilitychange"))
    await settle()

    expect(fetched).toHaveBeenCalledTimes(2)
    expect(state()).toMatchObject({ phase: "sealed" })
  })

  it("reads again only once when both online and visible follow a failed read", async () => {
    fetched.mockResolvedValueOnce(null).mockResolvedValueOnce(ARRIVED)
    const { refresh } = screen(startWith({ bank: bank(0) }))

    refresh.atZero()
    await settle()
    window.dispatchEvent(new Event("online"))
    document.dispatchEvent(new Event("visibilitychange"))
    await settle()

    expect(fetched).toHaveBeenCalledTimes(2)
  })

  it("never reads again after a read that worked", async () => {
    fetched.mockResolvedValue(ARRIVED)
    const { refresh } = screen(startWith({ bank: bank(0) }))

    refresh.atZero()
    await settle()
    window.dispatchEvent(new Event("online"))
    document.dispatchEvent(new Event("visibilitychange"))
    await settle()

    expect(fetched).toHaveBeenCalledTimes(1)
  })

  it("owes the retried read to a hand still in progress", async () => {
    fetched.mockResolvedValueOnce(null)
    const { refresh, host, state } = screen(startWith({ bank: bank(0) }))

    await refresh.refresh()
    host.apply(() => dealt())
    window.dispatchEvent(new Event("online"))
    await settle()

    expect(fetched).toHaveBeenCalledTimes(1)
    expect(state()).toMatchObject({ bankOwed: true })
  })

  it("stops listening once the screen leaves", async () => {
    fetched.mockResolvedValue(null)
    const { refresh } = screen(startWith({ bank: bank(0) }))

    refresh.atZero()
    await settle()
    refresh.stop()
    window.dispatchEvent(new Event("online"))
    document.dispatchEvent(new Event("visibilitychange"))
    await settle()

    expect(fetched).toHaveBeenCalledTimes(1)
  })
})
