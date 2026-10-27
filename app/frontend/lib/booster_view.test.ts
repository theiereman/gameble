import { describe, expect, it } from "vitest"
import { arming, cardStored, ejecting, legendarySignalled, openingStarted, revealAllStarted, revealMarked, revealStarted } from "./booster_opening"
import { bannerShown, idle, lock, locked } from "./booster_state"
import { CLICK_AFTER_DRAG, Layout, REVEAL_GUARD } from "./booster_types"
import { activation, controls, layoutApplied, layoutAsked, zoomClosed, zoomOpened, zoomStepped } from "./booster_view"
import { FIVE, VALVE, bank, dealt, revealedAll, startWith } from "./booster_fixtures"

describe("layoutAsked, layoutApplied", () => {
  it("keeps the layout the width asks for until the screen is idle", () => {
    const busy = revealStarted(dealt(), 0, false)
    const asked = layoutAsked(busy, "phone")
    expect(asked.pendingLayout).toBe("phone")
    expect(layoutAsked(asked, "phone")).toBe(asked)
    expect(layoutApplied(asked, true)).toBe(asked)
  })

  it("forgets a layout asked that is the one drawn", () => {
    const state = layoutAsked(startWith(), "wide")
    expect(layoutApplied(state, false)).toMatchObject({ pendingLayout: null, rebuilds: 0 })
    const settled = startWith()
    expect(layoutApplied(settled, false)).toBe(settled)
  })

  it("draws the hand again in the new layout: the revealed cards in the tray, the zoom and banner gone", () => {
    const state = bannerShown({ ...revealMarked(dealt(), 0, 0), zoom: 0 }, { tier: "epic", large: false, line: null, reduced: false })
    const rebuilt = layoutApplied(layoutAsked(state, "phone"), true)
    expect(rebuilt).toMatchObject({ layout: "phone", pendingLayout: null, rebuilds: state.rebuilds + 1, zoom: null, banner: null, focus: "card" })
    expect(rebuilt.stored).toEqual([true, false, false, false, false])
    const back = layoutApplied(layoutAsked(rebuilt, "narrow"), false)
    expect(back.stored).toEqual([false, false, false, false, false])
    expect(back.focus).toBe("card")
  })

  it("completes and celebrates a hand fully revealed", () => {
    const state = revealedAll(dealt(["epic"], { layout: "phone" }, [VALVE]))
    const rebuilt = layoutApplied(layoutAsked(state, "wide"), false)
    expect(rebuilt.status).toBe("complete")
    expect(rebuilt.celebration).toHaveLength(1)
  })
})

describe("zoomOpened, zoomClosed, zoomStepped", () => {
  const tray = () => {
    const state = dealt(FIVE, { layout: "phone" })
    return { ...revealedAll(state), stored: [true, false, true, true, false] }
  }

  it("opens a filled slot only when idle", () => {
    const state = tray()
    expect(zoomOpened(state, 2).zoom).toBe(2)
    expect(zoomOpened(state, 1)).toBe(state)
    const busy = lock(state)
    expect(zoomOpened(busy, 2)).toBe(busy)
  })

  it("steps to the filled neighbours, staying at either end", () => {
    const zoomed = zoomOpened(tray(), 2)
    expect(zoomStepped(zoomed, -1).zoom).toBe(0)
    expect(zoomStepped(zoomed, 1).zoom).toBe(3)
    const last = zoomStepped(zoomed, 1)
    expect(zoomStepped(last, 1)).toBe(last)
    const closed = tray()
    expect(zoomStepped(closed, 1)).toBe(closed)
  })

  it("closes, asking the focus back on its slot", () => {
    expect(zoomClosed(zoomOpened(tray(), 3))).toMatchObject({ zoom: null, focus: { slot: 3 } })
    expect(zoomClosed(tray()).focus).toBe("card")
  })
})

describe("activation", () => {
  it("reveals a face-down card and leaves for a revealed one past its guard", () => {
    const state = revealMarked(dealt(), 0, 1000)
    expect(activation(state, 1, 1000)).toBe("reveal")
    expect(activation(state, 0, 1000 + REVEAL_GUARD - 1)).toBe("none")
    expect(activation(state, 0, 1000 + REVEAL_GUARD)).toBe("leave")
    expect(activation(state, 9, 1000)).toBe("none")
  })

  it("never leaves while the navigation is locked, an opening or Reveal all runs", () => {
    const state = revealMarked(dealt(), 0, 0)
    const now = 10_000
    expect(activation(lock(state), 0, now)).toBe("none")
    expect(activation(revealAllStarted(state), 0, now)).toBe("none")
    expect(activation({ ...state, opening: true }, 0, now)).toBe("none")
  })

  it("stores a revealed card on the phone, unless the click ends a drag", () => {
    const state = revealMarked(dealt(FIVE, { layout: "phone" }), 0, 0)
    expect(activation(state, 0, 5000)).toBe("store")
    expect(activation(state, 0, 5000, 5000 - CLICK_AFTER_DRAG + 1)).toBe("none")
    expect(activation(state, 0, 5000, 5000 - CLICK_AFTER_DRAG)).toBe("store")
  })
})

describe("controls", () => {
  it("offers to open a sealed canister, Reveal all disabled", () => {
    const view = controls(startWith())
    expect(view).toMatchObject({ open: "open", openDisabled: false, busy: false, locked: false, revealAllDisabled: true, tone: "rest", hint: null, top: null })
  })

  it("says the reserve is empty, the opening disabled, except while opening", () => {
    expect(controls(startWith({ bank: bank(0) }))).toMatchObject({ open: "empty", openDisabled: true })
    const opening = arming(openingStarted(startWith({ bank: bank(1) })), "key")
    expect(controls({ ...opening, bank: bank(0) })).toMatchObject({ open: "open", openDisabled: false, busy: true, tone: "alert" })
  })

  it("holds the next one until every card is shown, and counts what is left", () => {
    const hand = revealMarked(dealt(), 0, 0)
    expect(controls(hand)).toMatchObject({ open: "next", openDisabled: true, revealAllDisabled: false, hint: { kind: "remaining", count: 4 } })
    expect(controls(revealedAll(hand))).toMatchObject({ openDisabled: false, revealAllDisabled: true, hint: { kind: "done", count: 5 } })
  })

  it("marks the controls busy and locked while anything holds the navigation", () => {
    expect(controls(lock(dealt()))).toMatchObject({ busy: true, locked: true })
    expect(controls({ ...dealt(), storing: true })).toMatchObject({ busy: true, revealAllDisabled: true })
    expect(controls(legendarySignalled(dealt(), 0))).toMatchObject({ revealAllDisabled: true, tone: "gold" })
  })

  it("tones the state line", () => {
    const tones = (["sealed", "arming", "ejecting", "inventory", "legendarySignal", "complete", "waiting"] as const).map((status) => controls({ ...startWith(), status }).tone)
    expect(tones).toEqual(["rest", "alert", "alert", "rest", "gold", "done", "rest"])
  })

  it("tells the phone's pile: tap, swipe, the plate under a revealed top card, done", () => {
    const pile = dealt(["common", "rare"], { layout: "phone" })
    expect(controls(pile)).toMatchObject({ top: 0, plate: null, hint: { kind: "tap" } })
    const shown = revealMarked(pile, 0, 0)
    expect(controls(shown)).toMatchObject({ top: 0, plate: 0, hint: { kind: "swipe" } })
    const away = cardStored(cardStored(revealMarked(shown, 1, 0), 0), 1)
    expect(controls(away)).toMatchObject({ top: null, plate: null, storedCount: 2, hint: { kind: "done", count: 2 } })
  })

  it("enables the zoom's steps toward filled neighbours", () => {
    const layout: Layout = "phone"
    const state = { ...revealedAll(dealt(FIVE, { layout })), stored: [true, false, true, false, false], zoom: 2 }
    expect(controls(state)).toMatchObject({ zoomPrevious: true, zoomNext: false })
    expect(controls({ ...state, zoom: null })).toMatchObject({ zoomPrevious: false, zoomNext: false })
  })
})
