import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  arming,
  cardStored,
  cardsDealt,
  openingAnswered,
  openingEnded,
  openingStarted,
  revealEnded,
  revealMarked,
  storeEnded,
  storeStarted,
} from "./booster_opening"
import { reflectChange } from "./booster_reflect"
import { lock, start, unlock } from "./booster_state"
import type { BoosterState } from "./booster_types"
import { FIVE, answerOf, bank, startWith } from "./booster_fixtures"
import type { ToastDetail } from "./events"

const GOALS = ["Roguelike", "Mes favoris"]

const dealtWithGoals = (state: BoosterState = startWith(), goals: string[] = GOALS): BoosterState => {
  const opening = arming(lock(openingStarted(state)), "key-1")
  return unlock(openingEnded(cardsDealt(openingAnswered(opening, answerOf(FIVE, [], 1, goals)))))
}

const revealedOneByOne = (state: BoosterState): BoosterState =>
  state.revealed.reduce((next, _, index) => revealEnded(revealMarked(next, index, 0), index, false), state)

describe("goals reached by an opening", () => {
  it("wait while the cards are face down, then are reached once with the last card revealed", () => {
    const dealt = dealtWithGoals()
    expect(dealt.goalsPending).toEqual(GOALS)
    expect(dealt.goalsReached).toEqual([])

    const threeShown = [0, 1, 2].reduce((next, index) => revealEnded(revealMarked(next, index, 0), index, false), dealt)
    expect(threeShown.goalsReached).toEqual([])

    const complete = revealedOneByOne(dealt)
    expect(complete.status).toBe("complete")
    expect(complete.goalsPending).toEqual([])
    expect(complete.goalsReached).toEqual(GOALS)
  })

  it("on the phone, are reached with the last card stored, or when the next capsule opens first", () => {
    const onPhone = dealtWithGoals(startWith({ layout: "phone" }), ["Roguelike"])
    const revealed = onPhone.revealed.reduce((next, _, index) => revealMarked(next, index, 0), onPhone)
    expect(revealed.goalsReached).toEqual([])

    const stored = revealed.stored.reduce(
      (next, _, index) => storeEnded(cardStored(storeStarted(next, index, false, 10_000), index), false),
      revealed,
    )
    expect(stored.goalsReached).toEqual(["Roguelike"])

    const nextOpened = openingStarted({ ...revealed, bank: { ...revealed.bank, available: 1, openable: 1 } })
    expect(nextOpened.goalsPending).toEqual([])
    expect(nextOpened.goalsReached).toEqual(["Roguelike"])
  })

  it("are none for an opening that reached none, and for an opened capsule shown again", () => {
    expect(revealedOneByOne(dealtWithGoals(startWith(), [])).goalsReached).toEqual([])

    const reopened = start({
      bank: bank(1),
      reserve: "standard",
      opened: answerOf(FIVE, [], 1, ["Roguelike"]),
      layout: "wide",
      now: 1000,
      celebrationRemembered: false,
      preview: false,
    })
    expect([reopened.goalsPending, reopened.goalsReached]).toEqual([[], []])
  })
})

describe("reflectChange", () => {
  let toasts: ToastDetail[]

  beforeEach(() => {
    toasts = []
    const target = new EventTarget()
    target.addEventListener("gameble:toast", (event) => toasts.push((event as CustomEvent<ToastDetail>).detail))
    vi.stubGlobal("window", target)
  })

  afterEach(() => vi.unstubAllGlobals())

  it("toasts each goal reached once, titled, and nothing on later changes", () => {
    const dealt = dealtWithGoals()
    const complete = revealedOneByOne(dealt)
    reflectChange(dealt, complete, undefined, "Objectif atteint", () => {})
    expect(toasts).toEqual([
      { title: "Objectif atteint", message: "Roguelike" },
      { title: "Objectif atteint", message: "Mes favoris" },
    ])

    reflectChange(complete, { ...complete, focus: null }, undefined, "Objectif atteint", () => {})
    expect(toasts).toHaveLength(2)
  })
})
