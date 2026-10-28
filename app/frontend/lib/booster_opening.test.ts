import { describe, expect, it } from "vitest"
import type { Rarity } from "./card_types"
import {
  arming,
  canOpen,
  canReveal,
  canRevealAll,
  canStore,
  cardStored,
  cardsDealt,
  ejecting,
  legendaryEnded,
  legendarySignalled,
  openingAnswered,
  openingEnded,
  openingRefused,
  openingStarted,
  resultHeadShown,
  retracted,
  retracting,
  revealAllEnded,
  revealAllPlan,
  revealAllStarted,
  revealEnded,
  revealMarked,
  revealStarted,
  storeEnded,
  storeStarted,
} from "./booster_opening"
import { bankFetchOwed, celebrate, lock } from "./booster_state"
import { BoosterState, REVEAL_GUARD } from "./booster_types"
import { activation } from "./booster_view"
import { FIVE, VALVE, answerOf, bank, dealt, revealedAll, startWith } from "./booster_fixtures"

describe("canOpen, openingStarted", () => {
  it("opens a sealed canister, the reason and the celebration cleared", () => {
    const state = { ...startWith(), reason: "Too fast" }
    expect(canOpen(state)).toBe(true)
    expect(openingStarted(state)).toMatchObject({
      opening: true,
      reason: null,
      celebration: null,
      celebrationPending: null,
    })
  })

  it("opens the next one only once every dealt card is revealed", () => {
    const state = dealt()
    expect(canOpen(state)).toBe(false)
    expect(openingStarted(state)).toBe(state)
    expect(canOpen(revealedAll(state))).toBe(true)
  })

  it("opens nothing while an opening, a reveal, Reveal all or a store runs, or with no pack", () => {
    const sealed = startWith()
    const hand = revealedAll(dealt())
    for (const busy of [
      openingStarted(sealed),
      { ...hand, revealing: [1] },
      { ...hand, revealingAll: true },
      { ...hand, storing: true },
      startWith({ bank: bank(0) }),
      arming(sealed, "key"),
    ]) {
      expect(canOpen(busy)).toBe(false)
      expect(openingStarted(busy)).toBe(busy)
    }
  })

  it("opens a special capsule while no standard capsule is available", () => {
    const state = startWith({ bank: bank(0, { special: 2, openable: 2 }), reserve: "special" })

    expect(canOpen(state)).toBe(true)
    expect(openingStarted(state).opening).toBe(true)
  })
})

describe("retracting, retracted", () => {
  it("hides the result head, then clears the hand and docks a new canister", () => {
    const hand = celebrate(revealedAll(dealt(["epic"], {}, [VALVE])))
    const sinking = retracting(hand)
    expect(sinking.headShown).toBe(false)
    expect(retracting(sinking)).toBe(sinking)
    const docked = retracted(sinking)
    expect(docked).toMatchObject({
      answer: null,
      revealed: [],
      stored: [],
      dealt: false,
      armed: false,
      celebration: null,
      canisterAway: false,
      status: "sealed",
    })
    expect(docked.docks).toBe(hand.docks + 1)
  })
})

describe("arming", () => {
  it("makes a new key, or keeps the one a lost answer left", () => {
    const fresh = arming(openingStarted(startWith()), "key-new")
    expect(fresh).toMatchObject({ phase: "opening", status: "arming", pendingKey: "key-new" })
    expect(arming({ ...startWith(), pendingKey: "key-kept" }, "key-new").pendingKey).toBe("key-kept")
  })
})

describe("openingRefused", () => {
  const running = () => ejecting(arming(lock(openingStarted(startWith())), "key-1"))

  it("disarms the canister, says why and drops the key after a refusal", () => {
    const refused = openingRefused(
      running(),
      { kind: "refused", code: "sign_in_required", message: "Sign in" },
      "Failed",
    )
    expect(refused).toMatchObject({
      phase: "sealed",
      status: "sealed",
      armed: false,
      opening: false,
      reason: "Sign in",
      pendingKey: null,
      focus: "open",
    })
  })

  it("keeps the key after a throttle or a failure", () => {
    expect(
      openingRefused(running(), { kind: "refused", code: "throttled", message: "Slow down" }, "Failed").pendingKey,
    ).toBe("key-1")
    const failed = openingRefused(running(), { kind: "failed" }, "Failed")
    expect(failed).toMatchObject({ pendingKey: "key-1", reason: "Failed" })
  })

  it("empties the bank with no pack left, the focus on the way back", () => {
    const state = running()
    const refused = openingRefused(state, { kind: "refused", code: "no_pack_available", message: "None" }, "Failed")
    expect(refused).toMatchObject({ phase: "empty", status: "waiting", focus: "back" })
    expect(refused.bank).toMatchObject({
      available: 0,
      special: 0,
      openable: 0,
      reserveFull: false,
      nextPackSize: null,
    })
    expect(refused.bankGeneration).toBe(state.bankGeneration + 1)
  })

  it("forgets an owed fetch after a refusal, not after a failure", () => {
    const owed = bankFetchOwed(running())
    expect(openingRefused(owed, { kind: "refused", code: "x", message: "m" }, "Failed").bankOwed).toBe(false)
    expect(openingRefused(owed, { kind: "failed" }, "Failed").bankOwed).toBe(true)
  })
})

describe("openingAnswered, ejecting, resultHeadShown, cardsDealt, openingEnded", () => {
  it("takes the answer: the bank replaced, the counts before, the cards face down, the key dropped", () => {
    const state = arming(lock(openingStarted(startWith())), "key-1")
    const answer = answerOf(FIVE, [VALVE], 1)
    const answered = openingAnswered(state, answer)
    expect(answered.bank).toEqual({
      available: 1,
      special: 0,
      openable: 1,
      reserveFull: false,
      nextSpecialKind: null,
      nextAvailableAt: null,
      serverTime: answer.serverTime,
      nextPackSize: 5,
    })
    expect(answered.bankGeneration).toBe(state.bankGeneration + 1)
    expect(answered.counts).toEqual(answer.tierCountsBefore)
    expect(answered.counts).not.toBe(answer.tierCountsBefore)
    expect(answered.celebrationPending).toBe(answer.setTiers)
    expect(answered.revealed).toEqual([false, false, false, false, false])
    expect(answered.stored).toEqual([false, false, false, false, false])
    expect(answered.pendingKey).toBeNull()
  })

  it("arms, shows the head, deals and ends on the hand, the focus on its card", () => {
    const answered = openingAnswered(arming(openingStarted(startWith()), "key-1"), answerOf(FIVE))
    const ejected = ejecting(answered)
    expect(ejected).toMatchObject({ armed: true, status: "ejecting" })
    const shown = resultHeadShown(ejected)
    expect(shown.headShown).toBe(true)
    expect(resultHeadShown(shown)).toBe(shown)
    const onTable = cardsDealt(shown)
    expect(onTable.dealt).toBe(true)
    expect(cardsDealt(onTable)).toBe(onTable)
    expect(openingEnded(onTable)).toMatchObject({
      canisterAway: true,
      status: "inventory",
      phase: "dealt",
      opening: false,
      focus: "card",
    })
  })
})

describe("canReveal, revealStarted", () => {
  it("starts a face-down card's reveal", () => {
    const state = dealt()
    expect(canReveal(state, 0, false)).toBe(true)
    expect(revealStarted(state, 0, false).revealing).toEqual([0])
  })

  it("marks a Légendaire's reveal as holding every other activation", () => {
    const state = revealStarted(dealt(["legendary", "common"]), 0, false)
    expect(state.legendaryRunning).toBe(true)
    expect(canReveal(state, 1, false)).toBe(false)
    expect(canReveal(state, 1, true)).toBe(true)
  })

  it("refuses a card revealed, revealing, missing, or one not from Reveal all while it runs", () => {
    const state = revealStarted(revealMarked(dealt(), 0, 0), 1, false)
    for (const [busy, index, fromAll] of [
      [state, 0, false],
      [state, 1, true],
      [state, 9, true],
      [revealAllStarted(dealt()), 2, false],
      [startWith(), 0, true],
    ] as const) {
      expect(canReveal(busy, index, fromAll)).toBe(false)
      expect(revealStarted(busy, index, fromAll)).toBe(busy)
    }
  })
})

describe("revealMarked", () => {
  it("shows the card, keeps when, and counts its tier", () => {
    const marked = revealMarked(dealt(), 3, 1234)
    expect(marked.revealed).toEqual([false, false, false, true, false])
    expect(marked.revealedAt[3]).toBe(1234)
    expect(marked.counts).toMatchObject({ epic: 1, common: 3 })
  })

  it("counts from nothing without counts before, and does nothing twice", () => {
    const state = { ...dealt(), counts: null }
    const marked = revealMarked(state, 0, 0)
    expect(marked.counts).toEqual({ common: 1, uncommon: 0, rare: 0, epic: 0, legendary: 0 })
    expect(revealMarked(marked, 0, 5)).toBe(marked)
    expect(revealMarked(marked, 9, 5)).toBe(marked)
  })
})

describe("legendarySignalled, legendaryEnded", () => {
  it("signals the Légendaire, its card shown dimmed around, then ends", () => {
    const signalled = legendarySignalled(dealt(["legendary"]), 0)
    expect(signalled).toMatchObject({ status: "legendarySignal", legendary: 0, legendaryRunning: true })
    expect(legendarySignalled(dealt(["legendary"]), null).legendary).toBeNull()
    expect(legendaryEnded(signalled)).toMatchObject({ status: "inventory", legendary: null, legendaryRunning: false })
  })
})

describe("revealEnded", () => {
  const throughReveal = (state: BoosterState, index: number, fromAll = false) =>
    revealEnded(revealMarked(revealStarted(state, index, fromAll), index, 0), index, fromAll)

  it("completes a row's hand with its last card: the focus on the next one", () => {
    const last = revealMarked(dealt(["common", "rare"]), 0, 0)
    const complete = throughReveal(last, 1)
    expect(complete).toMatchObject({ status: "complete", revealing: [], focus: "open" })
    expect(throughReveal({ ...last, bank: bank(0) }, 1).focus).toBe("back")
  })

  it("leaves the hand open while cards stay face down, from Reveal all, or on the phone", () => {
    expect(throughReveal(dealt(), 0).status).toBe("inventory")
    expect(throughReveal(revealMarked(dealt(["common", "rare"]), 0, 0), 1, true).status).toBe("inventory")
    expect(throughReveal(revealMarked(dealt(["common", "rare"], { layout: "phone" }), 0, 0), 1).status).toBe(
      "inventory",
    )
  })
})

describe("canRevealAll, revealAllPlan, revealAllStarted, revealAllEnded", () => {
  it("plans the face-down cards not revealing yet", () => {
    const state = revealStarted(revealMarked(dealt(["common", "legendary", "rare"]), 0, 0), 2, false)
    expect(revealAllPlan(state)).toEqual([{ index: 1, wait: "full" }])
    expect(revealAllPlan(startWith())).toEqual([])
  })

  it("runs once at a time, never during a Légendaire or a store", () => {
    const state = dealt()
    expect(canRevealAll(state)).toBe(true)
    const running = revealAllStarted(state)
    expect(running.revealingAll).toBe(true)
    expect(revealAllStarted(running)).toBe(running)
    expect(canRevealAll(legendarySignalled(state, 0))).toBe(false)
    expect(canRevealAll({ ...state, storing: true })).toBe(false)
    expect(canRevealAll(startWith())).toBe(false)
  })

  it("completes a row with every card revealed, the phone with every card stored", () => {
    const row = revealAllEnded(revealedAll(revealAllStarted(dealt())))
    expect(row).toMatchObject({ revealingAll: false, status: "complete", focus: "open" })
    const phone = revealedAll(revealAllStarted(dealt(["common"], { layout: "phone" })))
    expect(revealAllEnded(phone).status).toBe("inventory")
    expect(revealAllEnded(cardStored(phone, 0)).status).toBe("complete")
  })
})

describe("canStore, storeStarted, cardStored, storeEnded", () => {
  const onPhone = (tiers: Rarity[] = ["common", "rare"]) => revealMarked(dealt(tiers, { layout: "phone" }), 0, 1000)

  it("stores the revealed top card once its guard is over", () => {
    const state = onPhone()
    expect(canStore(state, 0, false, 1000 + REVEAL_GUARD - 1)).toBe(false)
    expect(canStore(state, 0, false, 1000 + REVEAL_GUARD)).toBe(true)
    expect(storeStarted(state, 0, false, 1000 + REVEAL_GUARD).storing).toBe(true)
  })

  it("refuses a card face down, not on top, in a row, or while anything runs", () => {
    const state = onPhone()
    const now = 1000 + REVEAL_GUARD
    for (const [busy, index] of [
      [state, 1],
      [revealMarked(state, 1, 0), 1],
      [revealMarked(dealt(["common"]), 0, 0), 0],
      [lock(state), 0],
      [{ ...state, storing: true }, 0],
      [revealAllStarted(state), 0],
      [revealStarted(state, 1, false), 0],
    ] as const) {
      expect(canStore(busy, index, false, now)).toBe(false)
      expect(storeStarted(busy, index, false, now)).toBe(busy)
    }
  })

  it("lets Reveal all store at once, past the guard and the lock", () => {
    const state = lock(revealAllStarted(onPhone()))
    expect(canStore(state, 0, true, 1000)).toBe(true)
  })

  it("puts the card in the tray, then the focus on the next top card", () => {
    const stored = cardStored(storeStarted(onPhone(), 0, false, 2000), 0)
    expect(stored.stored).toEqual([true, false])
    expect(cardStored(stored, 0)).toBe(stored)
    expect(storeEnded(stored, false)).toMatchObject({ storing: false, focus: "card", status: "inventory" })
  })

  it("completes the hand with the last card stored, but not from Reveal all", () => {
    const last = cardStored(storeStarted(onPhone(["epic"]), 0, false, 2000), 0)
    expect(storeEnded(last, false)).toMatchObject({ storing: false, status: "complete", focus: "open" })
    const fromAll = storeEnded(last, true)
    expect(fromAll).toMatchObject({ storing: false, status: "inventory" })
    expect(fromAll.focus).toBe(last.focus)
  })
})
