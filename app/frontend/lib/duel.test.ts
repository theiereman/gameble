import { describe, expect, it } from "vitest"
import {
  acceptsView,
  boardShown,
  choose,
  cleared,
  drawnCards,
  GUARD_MS,
  handShown,
  moveNumberFrom,
  ready,
  released,
  revealDismissed,
  revealSeen,
  REVEAL_MS,
  startDuel,
  viewShown,
  withReadiness,
} from "./duel"

describe("acceptsView", () => {
  it("takes only a view strictly newer than the one shown", () => {
    const state = startDuel(4)

    expect(acceptsView(state, 5)).toBe(true)
    expect(acceptsView(state, 4)).toBe(false)
    expect(acceptsView(state, 3)).toBe(false)
  })

  it("compares against the last view shown", () => {
    const state = viewShown(startDuel(4), 7)

    expect(state.moveNumber).toBe(7)
    expect(acceptsView(state, 7)).toBe(false)
    expect(acceptsView(state, 8)).toBe(true)
  })
})

describe("moveNumberFrom", () => {
  it("reads a non-negative whole number", () => {
    expect(moveNumberFrom("0")).toBe(0)
    expect(moveNumberFrom("21")).toBe(21)
  })

  it("reads nothing else", () => {
    expect(moveNumberFrom("-1")).toBeNull()
    expect(moveNumberFrom("1.5")).toBeNull()
    expect(moveNumberFrom("")).toBeNull()
    expect(moveNumberFrom("2a")).toBeNull()
    expect(moveNumberFrom(null)).toBeNull()
    expect(moveNumberFrom(undefined)).toBeNull()
  })
})

describe("choices", () => {
  const complete = choose(choose(choose(startDuel(1), "card", "2"), "stat", "release"), "direction", "low")

  it("keeps each choice, and changing a stat drops the direction that belonged to it", () => {
    expect(complete).toMatchObject({ card: "2", stat: "release", direction: "low" })
    expect(choose(complete, "card", "3")).toMatchObject({ card: "3", stat: "release", direction: "low" })
    expect(choose(complete, "stat", "rating")).toMatchObject({ stat: "rating", direction: null })
  })

  it("refuses a blocked choice", () => {
    const state = startDuel(1)

    expect(choose(state, "stat", "release", true)).toBe(state)
  })

  it("clears the latest choice first: direction, then stat, then card, then nothing", () => {
    const stat = cleared(complete)
    const card = cleared(stat)

    expect(stat).toMatchObject({ card: "2", stat: "release", direction: null })
    expect(card).toMatchObject({ card: "2", stat: null })
    const none = cleared(card)

    expect(none).toMatchObject({ card: null })
    expect(cleared(none)).toBe(none)
  })

  it("is ready for a call with all three, for an answer with a card", () => {
    expect(ready(complete, "call")).toBe(true)
    expect(ready(cleared(complete), "call")).toBe(false)
    expect(ready(cleared(complete), "answer")).toBe(true)
    expect(ready(startDuel(1), "answer")).toBe(false)
  })

  it("forgets the choices when the next board is shown", () => {
    expect(boardShown(complete, 5)).toMatchObject({
      moveNumber: 5,
      card: null,
      stat: null,
      direction: null,
      activeSince: null,
    })
  })
})

describe("press guard", () => {
  it("releases only once the guard has passed since the choices became complete", () => {
    const active = withReadiness(startDuel(1), true, 1000)

    expect(released(active, 1000 + GUARD_MS - 1)).toBe(false)
    expect(released(active, 1000 + GUARD_MS)).toBe(true)
  })

  it("keeps the first moment while the choices stay complete, and forgets it when they stop", () => {
    const active = withReadiness(startDuel(1), true, 1000)

    expect(withReadiness(active, true, 5000)).toBe(active)
    expect(withReadiness(active, false, 5000).activeSince).toBeNull()
    expect(released(withReadiness(active, false, 5000), 9000)).toBe(false)
  })
})

describe("reveal", () => {
  it("shows a round for three seconds from its first board, and a later board of the round does not restart it", () => {
    const first = revealSeen(startDuel(4), 2, 1000)
    const later = revealSeen(first, 2, 2500)

    expect(first.reveal).toEqual({ round: 2, endsAt: 1000 + REVEAL_MS })
    expect(later).toBe(first)
  })

  it("never shows a dismissed round again, and shows a newer one", () => {
    const dismissed = revealDismissed(revealSeen(startDuel(4), 2, 1000))

    expect(dismissed).toMatchObject({ dismissed: 2, reveal: null })
    expect(revealSeen(dismissed, 2, 9000).reveal).toBeNull()
    expect(revealSeen(dismissed, 3, 9000).reveal?.round).toBe(3)
  })

  it("has nothing to show on a board without a reveal", () => {
    expect(revealSeen(revealSeen(startDuel(4), 2, 1000), null, 2000).reveal).toBeNull()
  })
})

describe("drawn cards", () => {
  it("names the cards that were not in the hand shown before, and none at the first board", () => {
    const first = startDuel(1)
    const shown = handShown(first, ["1", "2", "3"])

    expect(drawnCards(first, ["1", "2", "3"])).toEqual([])
    expect(drawnCards(shown, ["1", "3", "4"])).toEqual(["4"])
  })
})
