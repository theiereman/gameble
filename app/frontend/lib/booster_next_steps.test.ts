import { describe, expect, it } from "vitest"
import {
  arming,
  cardStored,
  cardsDealt,
  openingAnswered,
  openingEnded,
  openingStarted,
  resultHeadShown,
} from "./booster_opening"
import { bankChanged, lock, unlock } from "./booster_state"
import type { Layout } from "./booster_types"
import { nextStepsShown } from "./booster_view"
import { FIVE, answerOf, bank, revealedAll, startWith } from "./booster_fixtures"

const opened = (layout: Layout = "wide") => arming(lock(openingStarted(startWith({ bank: bank(1), layout }))), "key-1")

const lastDealt = (layout: Layout = "wide") =>
  unlock(openingEnded(cardsDealt(resultHeadShown(openingAnswered(opened(layout), answerOf(FIVE, [], 0))))))

const storedAll = (state: ReturnType<typeof lastDealt>) =>
  state.stored.reduce((next, _, index) => cardStored(next, index), state)

describe("nextStepsShown", () => {
  it("shows on a screen opened on an empty reserve", () => {
    expect(nextStepsShown(startWith({ bank: bank(0) }))).toBe(true)
  })

  it("stays hidden while a capsule is left, standard or special", () => {
    expect(nextStepsShown(startWith({ bank: bank(2) }))).toBe(false)
    expect(nextStepsShown(startWith({ bank: bank(0, { special: 1, openable: 1 }) }))).toBe(false)
  })

  it("stays hidden while the last capsule opens and its hand is still being played", () => {
    expect(nextStepsShown(opened())).toBe(false)
    const answered = openingAnswered(opened(), answerOf(FIVE, [], 0))
    expect(answered.phase).toBe("opening")
    expect(answered.bank.available + answered.bank.special).toBe(0)
    expect(nextStepsShown(answered)).toBe(false)
    expect(nextStepsShown(lastDealt())).toBe(false)
    const phone = revealedAll(lastDealt("phone"))
    expect(nextStepsShown(phone)).toBe(false)
  })

  it("shows once the last hand is revealed on a desktop, or stored on a phone", () => {
    expect(nextStepsShown(revealedAll(lastDealt()))).toBe(true)
    expect(nextStepsShown(storedAll(revealedAll(lastDealt("phone"))))).toBe(true)
  })

  it("hides again when a capsule arrives", () => {
    const done = revealedAll(lastDealt())
    expect(nextStepsShown(bankChanged(done, bank(1)))).toBe(false)
    expect(nextStepsShown(bankChanged(done, bank(0, { special: 1, openable: 1 })))).toBe(false)
  })
})
