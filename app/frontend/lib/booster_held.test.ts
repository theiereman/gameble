import { describe, expect, it } from "vitest"
import {
  arming,
  bankFetched,
  cardsDealt,
  confirmationRefused,
  heldEntry,
  heldOpened,
  lock,
  openingAnswered,
  openingConfirmed,
  openingEnded,
  openingRoute,
  openingStarted,
  resultHeadShown,
  retracted,
  retracting,
  revealEnded,
  revealMarked,
  revealModeReached,
  unlock,
  type BoosterState,
} from "./booster"
import { FIVE, VALVE, bank, cardOf, confirmationOf, heldOf, startWith } from "./booster_fixtures"
import type { BoosterStart } from "./booster_types"
import type { HeldCapsule } from "./opening"

const HELD = heldOf(FIVE, "held-1")
const NEXT = heldOf(["rare", "rare", "rare"], "held-2")

const withHeld = (overrides: Partial<BoosterStart> = {}, held: HeldCapsule = HELD): BoosterState =>
  startWith({ bank: bank(2), held: { standard: held, special: null }, ...overrides })

function openedHeld(state: BoosterState = withHeld()): BoosterState {
  const armed = arming(lock(openingStarted(state)), null)
  return heldOpened(armed, heldEntry(armed, "key-1")!)
}

const dealtHeld = (state: BoosterState = withHeld()): BoosterState =>
  unlock(openingEnded(cardsDealt(resultHeadShown(openedHeld(state)))))

const revealedOneByOne = (state: BoosterState): BoosterState =>
  state.revealed.reduce((next, _, index) => revealEnded(revealMarked(next, index, 0), index, false), state)

describe("a held capsule", () => {
  it("opens without the network: its cards and faces, one capsule less in its reserve, its confirmation queued", () => {
    const state = withHeld()
    expect(openingRoute(state)).toBe("held")

    const opened = openedHeld(state)

    expect(opened.answer?.pack.token).toBe("held-1")
    expect(opened.answer?.cards).toBe(HELD.cards)
    expect(opened.provisional).toBe(true)
    expect(opened.bank).toMatchObject({ available: 1, openable: 1 })
    expect(opened.bankGeneration).toBe(state.bankGeneration + 1)
    expect(opened.held.standard).toBeNull()
    expect(opened.confirming).toEqual([{ token: "held-1", key: "key-1", reserve: "standard" }])
    expect(opened.counts).toEqual(HELD.tierCountsBefore)
    expect(opened.celebrationPending).toBeNull()
    expect(opened.revealed).toEqual([false, false, false, false, false])
  })

  it("keeps a token-less key it was holding for a lost opening", () => {
    expect(openedHeld({ ...withHeld(), pendingKey: "lost" }).pendingKey).toBe("lost")
  })

  it("opens only the capsule its entry names, in its reserve", () => {
    const armed = arming(lock(openingStarted(withHeld())), null)
    expect(heldOpened(armed, { token: "other", key: "k", reserve: "standard" })).toBe(armed)
    expect(heldOpened(armed, { token: "held-1", key: "k", reserve: "special" })).toBe(armed)
  })

  it("takes the waiting path only with no held capsule and nothing pending for the reserve", () => {
    expect(openingRoute(startWith())).toBe("send")
    const pending = { ...startWith(), confirming: [{ token: "t", key: "k", reserve: "standard" as const }] }
    expect(openingRoute(pending)).toBe("await")
    expect(openingRoute({ ...pending, reserve: "special" })).toBe("send")
  })
})

describe("openingConfirmed", () => {
  it("adopts the server's bank, counts, first copies, set tiers and goals while the hand is on the table", () => {
    const hand = revealMarked(dealtHeld(), 0, 0)
    const answer = confirmationOf(HELD, { setTiers: [VALVE], available: 4, goalsReached: ["Roguelike"], next: NEXT })

    const confirmed = openingConfirmed(hand, "held-1", answer)

    expect(confirmed.provisional).toBe(false)
    expect(confirmed.confirming).toEqual([])
    expect(confirmed.bank.available).toBe(4)
    expect(confirmed.counts).toEqual({ common: 5, uncommon: 1, rare: 0, epic: 0, legendary: 0 })
    expect(confirmed.celebrationPending).toEqual([VALVE])
    expect(confirmed.goalsPending).toEqual(["Roguelike"])
    expect(confirmed.revealed).toEqual(hand.revealed)
    expect(confirmed.answer).toBe(hand.answer)
    expect(confirmed.rebuilds).toBe(hand.rebuilds)
    expect(confirmed.celebration).toBeNull()

    const done = revealedOneByOne(confirmed)
    expect(done.status).toBe("complete")
    expect(done.celebration).not.toBeNull()
    expect(done.goalsReached).toEqual(["Roguelike"])
  })

  it("plays the celebration and the goals at once when it lands after the hand is done", () => {
    const done = revealedOneByOne(dealtHeld())
    expect(done.status).toBe("complete")
    expect(done.celebration).toBeNull()

    const confirmed = openingConfirmed(
      done,
      "held-1",
      confirmationOf(HELD, { setTiers: [VALVE], goalsReached: ["Rpg"] }),
    )

    expect(confirmed.celebration).not.toBeNull()
    expect(confirmed.goalsReached).toEqual(["Rpg"])
  })

  it("follows the server when it answers other cards: those cards are redrawn face down, the others stay", () => {
    const hand = revealMarked(revealMarked(dealtHeld(), 0, 10), 1, 20)
    const server = confirmationOf({
      ...HELD,
      cards: HELD.cards.map((card, index) => (index === 1 ? cardOf("legendary", "other") : card)),
    })

    const confirmed = openingConfirmed(hand, "held-1", server)

    expect(confirmed.answer).toBe(server)
    expect(confirmed.revealed).toEqual([true, false, false, false, false])
    expect(confirmed.revealedAt).toEqual([10, undefined, undefined, undefined, undefined])
    expect(confirmed.rebuilds).toBe(hand.rebuilds + 1)
    expect(confirmed.counts).toEqual({ common: 5, uncommon: 1, rare: 0, epic: 0, legendary: 0 })
  })

  it("takes the next capsule of the reserve as its held capsule, so the following touch is instant", () => {
    const confirmed = openingConfirmed(revealedOneByOne(dealtHeld()), "held-1", confirmationOf(HELD, { next: NEXT }))
    expect(confirmed.held.standard).toBe(NEXT)
    expect(openingRoute(confirmed)).toBe("held")
  })

  it("updates only the bank and the held capsule for a capsule no longer on the table", () => {
    const away = retracted(retracting(revealedOneByOne(dealtHeld())))
    const confirmed = openingConfirmed(
      away,
      "held-1",
      confirmationOf(HELD, { available: 3, next: NEXT, goalsReached: ["Rpg"] }),
    )

    expect(confirmed.answer).toBeNull()
    expect(confirmed.bank.available).toBe(3)
    expect(confirmed.held.standard).toBe(NEXT)
    expect(confirmed.goalsReached).toEqual(["Rpg"])
  })

  it("does not offer a next capsule that is itself still waiting for its confirmation", () => {
    const first = { token: "first", key: "k0", reserve: "standard" as const }
    const state = { ...dealtHeld(), confirming: [first, ...dealtHeld().confirming] }

    const confirmed = openingConfirmed(
      state,
      "first",
      confirmationOf(heldOf(FIVE, "first"), { available: 2, next: HELD }),
    )

    expect(confirmed.held.standard).toBeNull()
    expect(confirmed.bank.available).toBe(1)
    expect(confirmed.provisional).toBe(true)
  })

  it("keeps the local count of the other reserve while its own confirmation is pending", () => {
    const special = { token: "spec", key: "k2", reserve: "special" as const }
    const state = { ...dealtHeld(), bank: { ...dealtHeld().bank, special: 1, openable: 2 } }
    const pending = { ...state, confirming: [...state.confirming, special] }
    const answer = confirmationOf(HELD, { available: 1 })

    const confirmed = openingConfirmed(pending, "held-1", {
      ...answer,
      bank: { ...answer.bank, special: 2, openable: 3 },
    })

    expect(confirmed.bank).toMatchObject({ available: 1, special: 1, openable: 2 })
  })

  it("ignores a token it is not waiting for", () => {
    const hand = dealtHeld()
    expect(openingConfirmed(hand, "unknown", confirmationOf(HELD))).toBe(hand)
  })
})

describe("the reveal mode of a held capsule", () => {
  it("waits for the confirmation, then is due once", () => {
    const hand = dealtHeld()
    const done = revealedOneByOne(hand)
    expect(revealModeReached(hand, done)).toBeNull()
    expect(done.revealDue).toBeNull()

    const confirmed = openingConfirmed(done, "held-1", confirmationOf(HELD))
    expect(confirmed.revealDue).toEqual({ token: "held-1", url: "/pack/held-1/reveal", mode: "one_by_one" })
  })

  it("is owed by a hand put away before its confirmation, and due when it lands", () => {
    const away = retracted(retracting(revealedOneByOne(dealtHeld())))
    expect(away.revealsOwed).toEqual([{ token: "held-1", url: "/pack/held-1/reveal", mode: "one_by_one" }])

    const confirmed = openingConfirmed(away, "held-1", confirmationOf(HELD))
    expect(confirmed.revealsOwed).toEqual([])
    expect(confirmed.revealDue?.token).toBe("held-1")
  })

  it("is never due for a refused confirmation", () => {
    const away = retracted(retracting(revealedOneByOne(dealtHeld())))
    const refused = confirmationRefused(away, "held-1")
    expect(refused.confirming).toEqual([])
    expect(refused.revealsOwed).toEqual([])
    expect(refused.revealDue).toBeNull()
  })
})

describe("a refused confirmation of the hand on the table", () => {
  it("leaves the hand no longer provisional, so putting it away owes no reveal", () => {
    const refused = confirmationRefused(revealedOneByOne(dealtHeld()), "held-1")
    expect(refused.provisional).toBe(false)
    expect(retracted(retracting(refused)).revealsOwed).toEqual([])
  })
})

describe("the counts of a provisional hand", () => {
  it("start from the live counts rather than the held capsule's counts from page load", () => {
    const special = heldOf(["epic", "epic", "epic"], "special-1")
    const live = { common: 9, uncommon: 2, rare: 1, epic: 0, legendary: 0 }
    const state = {
      ...withHeld({ bank: bank(2, { special: 1, openable: 3 }) }),
      held: { standard: null, special },
      reserve: "special" as const,
      counts: live,
    }
    expect(openedHeld(state).counts).toEqual(live)
    expect(openedHeld({ ...state, counts: null }).counts).toEqual(special.tierCountsBefore)
  })
})

describe("a capsule queued but not yet confirmed", () => {
  const queued = [{ token: "held-1", key: "key-1", reserve: "standard" as const }]

  it("is not shown as held again after a reload, and its reserve counts one less", () => {
    const reloaded = withHeld({ confirming: queued })
    expect(reloaded.held.standard).toBeNull()
    expect(reloaded.bank).toMatchObject({ available: 1, openable: 1 })
    expect(openingRoute(reloaded)).toBe("await")
  })

  it("is skipped the same way in a fetched bank", () => {
    const state = { ...startWith(), confirming: queued }
    const fetched = bankFetched(state, bank(3), state.bankGeneration, { standard: HELD, special: null })
    expect(fetched.held.standard).toBeNull()
    expect(fetched.bank.available).toBe(2)

    const other = bankFetched(state, bank(3), state.bankGeneration, { standard: NEXT, special: null })
    expect(other.held.standard).toBe(NEXT)
    expect(other.bank.available).toBe(3)
  })

  it("keeps the held capsules when the bank answer carries none", () => {
    const state = withHeld()
    expect(bankFetched(state, bank(3), state.bankGeneration).held).toBe(state.held)
  })
})

describe("the waiting path", () => {
  it("takes the answer's next capsule as the reserve's held capsule", () => {
    const state = arming(lock(openingStarted(startWith())), "key-1")
    const opened = openingAnswered(state, { ...confirmationOf(HELD), next: NEXT })
    expect(opened.held.standard).toBe(NEXT)
    expect(opened.provisional).toBe(false)
  })
})
