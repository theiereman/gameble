import { describe, expect, it } from "vitest"
import {
  arming,
  cardStored,
  cardsDealt,
  openingAnswered,
  openingEnded,
  openingStarted,
  resultHeadShown,
  retracted,
} from "./booster_opening"
import { bankChanged, celebrate, celebrationDismissed, lock, unlock } from "./booster_state"
import type { Layout } from "./booster_types"
import { canisterDocks, nextCapsuleWaiting } from "./booster_view"
import { FIVE, VALVE, answerOf, bank, revealedAll, startWith } from "./booster_fixtures"

const opened = (layout: Layout = "wide") => arming(lock(openingStarted(startWith({ bank: bank(1), layout }))), "key-1")

const lastDealt = (layout: Layout = "wide") =>
  unlock(openingEnded(cardsDealt(resultHeadShown(openingAnswered(opened(layout), answerOf(FIVE, [], 0))))))

const storedAll = (state: ReturnType<typeof lastDealt>) =>
  state.stored.reduce((next, _, index) => cardStored(next, index), state)

describe("nextCapsuleWaiting", () => {
  it("brings the next capsule back on the phone once the hand is stored and a capsule is left", () => {
    const hand = bankChanged(revealedAll(lastDealt("phone")), bank(2))

    expect(nextCapsuleWaiting(hand)).toBe(false)
    expect(nextCapsuleWaiting(storedAll(hand))).toBe(true)
  })

  it("waits for a set result reached by the hand to be dismissed, which hands the focus to the open button", () => {
    const opened = arming(lock(openingStarted(startWith({ bank: bank(2), layout: "phone" }))), "key-1")
    const hand = unlock(openingEnded(cardsDealt(resultHeadShown(openingAnswered(opened, answerOf(FIVE, [VALVE], 1))))))
    const stored = storedAll(celebrate(revealedAll(hand)))

    expect(stored.celebration).not.toBeNull()
    expect(nextCapsuleWaiting(stored)).toBe(false)
    const dismissed = celebrationDismissed(stored)
    expect(nextCapsuleWaiting(dismissed)).toBe(true)
    expect(dismissed.focus).toBe("open")
  })

  it("brings none back once the reserve is empty, nor where the hand stays on the table", () => {
    expect(nextCapsuleWaiting(bankChanged(storedAll(revealedAll(lastDealt("phone"))), bank(0)))).toBe(false)
    expect(nextCapsuleWaiting(bankChanged(revealedAll(lastDealt()), bank(2)))).toBe(false)
  })
})

describe("canisterDocks", () => {
  it("docks a fresh capsule when the next one comes back, and none again when it is opened", () => {
    const hand = bankChanged(revealedAll(lastDealt("phone")), bank(2))
    const waiting = storedAll(hand)

    expect(canisterDocks(waiting)).toBe(canisterDocks(hand) + 1)
    expect(canisterDocks(retracted(waiting))).toBe(canisterDocks(waiting))
  })
})
