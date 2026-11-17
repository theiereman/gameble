// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { BoosterState } from "./booster"
import { dealt } from "./booster_fixtures"
import { CardMarket, marketMoveKey, type BoosterMarket } from "./booster_market"

const MARKET: BoosterMarket = {
  entrustUrl: "/en/market/entrust",
  sellUrl: "/en/market/sell",
  settings: "settings-token",
  duration: 24,
  entrustment: { common: 5, uncommon: 12 },
  minimumPrice: { common: 20, uncommon: 40 },
}

describe("CardMarket", () => {
  let state: BoosterState
  let fetch: ReturnType<typeof vi.fn>
  let market: CardMarket
  const key = (index: number) => marketMoveKey("pack-token", index)

  beforeEach(() => {
    fetch = vi.fn().mockResolvedValue(new Response(null, { status: 201 }))
    vi.stubGlobal("fetch", fetch)
    state = dealt()
    market = new CardMarket({
      market: MARKET,
      state: () => state,
      apply: (transition) => (state = transition(state)),
      failed: "failed",
    })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("shows the entrust at once and posts it only when a new capsule opens, the undo gone", async () => {
    market.move(0, "entrust")
    expect(state.marketMoves[key(0)]).toEqual({ place: "entrust", amount: 5, sent: false })
    expect(fetch).not.toHaveBeenCalled()

    market.flush(true)
    await vi.waitFor(() => expect(fetch).toHaveBeenCalledOnce())

    expect(state.marketMoves[key(0)]?.sent).toBe(true)
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe("/en/market/entrust")
    expect(String(init.body)).toBe("selection=common-0%3A1%3D1&settings=settings-token")
    market.undo(0)
    expect(state.marketMoves[key(0)]?.sent).toBe(true)
  })

  it("sends nothing for a move undone before leaving", () => {
    market.move(1, "sell")
    market.undo(1)
    market.flush(true)

    expect(fetch).not.toHaveBeenCalled()
    expect(state.marketMoves).toEqual({})
  })

  it("posts the waiting moves when the page is left", async () => {
    market.move(0, "entrust")
    window.dispatchEvent(new Event("pagehide"))

    await vi.waitFor(() => expect(fetch).toHaveBeenCalledOnce())
    expect(fetch.mock.calls[0][1].keepalive).toBe(true)
  })

  it("sells at the rarity's minimum price for the preselected duration", async () => {
    market.move(1, "sell")
    market.flush(false)
    await vi.waitFor(() => expect(fetch).toHaveBeenCalledOnce())

    const body = new URLSearchParams(String(fetch.mock.calls[0][1].body))
    expect(Object.fromEntries(body)).toEqual({
      ref: "uncommon-1:1",
      starting_price: "40",
      duration_hours: "24",
      settings: "settings-token",
    })
  })

  it("drops the overlay and toasts the server's refusal", async () => {
    fetch.mockResolvedValue(Response.json({ error: { message: "No card fits." } }, { status: 422 }))
    const toasts: string[] = []
    window.addEventListener("gameble:toast", (event) => toasts.push((event as CustomEvent).detail.message))

    market.move(0, "entrust")
    market.flush(true)

    await vi.waitFor(() => expect(toasts).toEqual(["No card fits."]))
    expect(state.marketMoves).toEqual({})
  })
})
