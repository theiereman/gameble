import { describe, expect, it } from "vitest"
import {
  openingAnswered,
  openingStarted,
  retracted,
  revealAllStarted,
  revealMarked,
  revealModeReached,
} from "./booster_opening"
import { focusGiven } from "./booster_state"
import type { BoosterState } from "./booster_types"
import { FIVE, answerOf, dealt, revealedAll, startWith } from "./booster_fixtures"

function modesWhileMarking(state: BoosterState, indexes: number[]): (string | null)[] {
  const modes: (string | null)[] = []
  indexes.reduce((before, index) => {
    const after = revealMarked(before, index, 0)
    modes.push(revealModeReached(before, after))
    return after
  }, state)
  return modes
}

describe("revealModeReached", () => {
  it("gives one_by_one only when the last card turned by hand is face up", () => {
    expect(modesWhileMarking(dealt(), [0, 1, 2, 3, 4])).toEqual([null, null, null, null, "one_by_one"])
  })

  it("gives one_by_one whatever order the cards are turned in", () => {
    expect(modesWhileMarking(dealt(), [4, 2, 0, 3, 1])).toEqual([null, null, null, null, "one_by_one"])
  })

  it("gives all when Reveal all turns every card", () => {
    const running = revealAllStarted(dealt())
    expect(running.revealAllUsed).toBe(true)
    expect(modesWhileMarking(running, [0, 1, 2, 3, 4])).toEqual([null, null, null, null, "all"])
  })

  it("gives all when Reveal all starts after some cards were turned by hand", () => {
    const byHand = revealMarked(revealMarked(dealt(), 0, 0), 3, 0)
    expect(byHand.revealAllUsed).toBe(false)
    expect(modesWhileMarking(revealAllStarted(byHand), [1, 2, 4])).toEqual([null, null, "all"])
  })

  it("starts every new opening and every screen with Reveal all unused", () => {
    expect(startWith().revealAllUsed).toBe(false)
    const used = revealedAll(revealAllStarted(dealt()))
    const next = openingAnswered(retracted(openingStarted(used)), answerOf(FIVE))
    expect(next.revealAllUsed).toBe(false)
    expect(modesWhileMarking(next, [0, 1, 2, 3, 4])).toEqual([null, null, null, null, "one_by_one"])
  })

  it("gives nothing for a capsule restored face up", () => {
    const restored = startWith({ opened: answerOf(FIVE) })
    expect(revealModeReached(startWith(), restored)).toBeNull()
    expect(revealModeReached(restored, focusGiven(restored))).toBeNull()
    expect(revealModeReached(restored, revealAllStarted(restored))).toBeNull()
  })

  it("gives nothing for a transition that leaves the cards as they were", () => {
    const state = dealt()
    expect(revealModeReached(state, state)).toBeNull()
    expect(revealModeReached(state, focusGiven(state))).toBeNull()
    const done = revealedAll(state)
    expect(revealModeReached(done, done)).toBeNull()
    expect(revealModeReached(done, revealMarked(done, 0, 0))).toBeNull()
    expect(revealModeReached(startWith(), startWith())).toBeNull()
  })

  it("gives nothing when the answer changes between the two states", () => {
    const before = dealt()
    const other = revealedAll(dealt())
    expect(revealModeReached(before, other)).toBeNull()
    expect(revealModeReached(revealedAll(before), retracted(revealedAll(before)))).toBeNull()
  })
})
