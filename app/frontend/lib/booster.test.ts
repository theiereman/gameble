import { describe, expect, it } from "vitest"
import {
  CLICK_AFTER_DRAG,
  NARROW_QUERY,
  PHONE_QUERY,
  REVEAL_GUARD,
  activation,
  arming,
  bankChanged,
  bankDue,
  bankFetchOwed,
  bankFetched,
  bannerEnded,
  bannerShown,
  canOpen,
  canReveal,
  canRevealAll,
  canStore,
  cardStored,
  cardsDealt,
  celebrate,
  celebrationSpoken,
  celebrationToAnnounce,
  controls,
  countdownAtZero,
  countsAfterReveal,
  ejecting,
  faceSize,
  focusGiven,
  focusTarget,
  idle,
  keyAfter,
  layoutApplied,
  layoutAsked,
  layoutFor,
  legendaryEnded,
  legendarySignalled,
  lock,
  lockReleased,
  locked,
  openingAnswered,
  openingEnded,
  openingRefused,
  openingStarted,
  owedBankTaken,
  planRevealAll,
  resultHeadShown,
  retracted,
  retracting,
  revealAllEnded,
  revealAllPlan,
  revealAllStarted,
  revealEnded,
  revealMarked,
  revealStarted,
  revealingOpening,
  shownCelebration,
  start,
  storeEnded,
  storeStarted,
  storedAfterRebuild,
  topOfPile,
  unlock,
  zoomClosed,
  zoomNeighbour,
  zoomOpened,
  zoomStepped,
  type BoosterStart,
  type BoosterState,
  type Layout,
} from "./booster"
import type { BoosterBank, BoosterStatus } from "./booster_props"
import type { Rarity } from "./card_types"
import type { OpeningAnswer, OpeningCard, OpeningSetTier } from "./opening"

const bank = (available: number, extra: Partial<BoosterBank> = {}): BoosterBank => ({
  available,
  reserveFull: false,
  nextAvailableAt: "2026-10-26T12:00:00.000Z",
  serverTime: "2026-10-26T11:00:00.000Z",
  nextPackSize: available > 0 ? 5 : null,
  ...extra,
})

const cardOf = (tier: Rarity, slug: string = tier): OpeningCard => ({
  slug,
  season: 1,
  tier,
  coverUrl: "",
  title: slug,
  year: 2020,
  label: slug,
  faces: { s: "", m: "", xl: "" },
})

const VALVE: OpeningSetTier = {
  kind: "studio",
  key: "valve",
  name: "Valve",
  tier: "complete",
  required: 1,
  held: 1,
  total: 1,
  thresholds: [],
  url: "/en/library/studio/valve",
}

const answerOf = (tiers: Rarity[], setTiers: OpeningSetTier[] = [], available = 1): OpeningAnswer => ({
  pack: { token: "pack-token", kind: "regular", cardBack: "standard", url: "/pack" },
  cards: tiers.map((tier, index) => cardOf(tier, `${tier}-${index}`)),
  bank: { available, reserveFull: false, nextAvailableAt: null, scheduledAt: [], nextPackSize: available > 0 ? 5 : null },
  serverTime: "2026-10-26T11:00:01.000Z",
  tierCountsBefore: { common: 3, uncommon: 0, rare: 0, epic: 0, legendary: 0 },
  setTiers,
  unlockedCardBacks: [],
})

const startWith = (overrides: Partial<BoosterStart> = {}): BoosterState =>
  start({ bank: bank(2), opened: null, layout: "wide", now: 1000, celebrationRemembered: false, preview: false, ...overrides })

const FIVE: Rarity[] = ["common", "uncommon", "rare", "epic", "common"]

const dealt = (tiers: Rarity[] = FIVE, overrides: Partial<BoosterStart> = {}, setTiers: OpeningSetTier[] = []): BoosterState => {
  const opening = arming(lock(openingStarted(startWith(overrides))), "key-1")
  return unlock(openingEnded(cardsDealt(resultHeadShown(openingAnswered(opening, answerOf(tiers, setTiers))))))
}

const revealedAll = (state: BoosterState, now = 0): BoosterState =>
  state.revealed.reduce((next, _, index) => revealMarked(next, index, now), state)

describe("layouts", () => {
  it("are the phone under 720px, the narrow row under 900px, the wide row above", () => {
    expect(layoutFor(true, true)).toBe("phone")
    expect(layoutFor(false, true)).toBe("narrow")
    expect(layoutFor(false, false)).toBe("wide")
    expect([PHONE_QUERY, NARROW_QUERY]).toEqual(["(max-width: 719px)", "(max-width: 899px)"])
  })

  it("deal xl on the phone, s in the narrow row, m in the wide one", () => {
    expect(faceSize("phone")).toBe("xl")
    expect(faceSize("narrow")).toBe("s")
    expect(faceSize("wide")).toBe("m")
  })
})

describe("revealingOpening", () => {
  it("is revealing from the canister arming until every card is shown", () => {
    const revealing: BoosterStatus[] = ["arming", "ejecting", "inventory", "legendarySignal"]
    revealing.forEach((status) => expect(revealingOpening(status)).toBe(true))
  })

  it("is not revealing while sealed, waiting for a pack or complete", () => {
    expect(revealingOpening("sealed")).toBe(false)
    expect(revealingOpening("waiting")).toBe(false)
    expect(revealingOpening("complete")).toBe(false)
  })
})

describe("planRevealAll", () => {
  it("lists the face-down cards in order, a legendary awaited in full", () => {
    expect(planRevealAll(["common", "legendary", "rare", "legendary", "epic"], [false, false, true, false, false])).toEqual([
      { index: 0, wait: "gap" },
      { index: 1, wait: "full" },
      { index: 3, wait: "full" },
      { index: 4, wait: "gap" },
    ])
    expect(planRevealAll(["common"], [true])).toEqual([])
  })
})

describe("keyAfter", () => {
  const key = "3c1f9a2e-7d4b-4c8a-b5e6-0f2d9e8a1b7c"

  it("keeps the key after an unknown outcome or a throttle", () => {
    expect(keyAfter({ kind: "failed" }, key)).toBe(key)
    expect(keyAfter({ kind: "refused", code: "throttled" }, key)).toBe(key)
  })

  it("drops it after a success or any other refusal", () => {
    expect(keyAfter({ kind: "opened" }, key)).toBeNull()
    expect(keyAfter({ kind: "refused", code: "no_pack_available" }, key)).toBeNull()
    expect(keyAfter({ kind: "refused", code: "sign_in_required" }, key)).toBeNull()
  })
})

describe("countsAfterReveal", () => {
  it("adds one copy to the tier, leaving the counts given as they were", () => {
    const counts = { common: 3, uncommon: 0, rare: 1, epic: 0, legendary: 0 }
    expect(countsAfterReveal(counts, "rare")).toEqual({ common: 3, uncommon: 0, rare: 2, epic: 0, legendary: 0 })
    expect(counts.rare).toBe(1)
  })
})

describe("topOfPile", () => {
  it("has on top the first card not stored, none once all are", () => {
    expect(topOfPile([false, false, false], [false, false, false])).toBe(0)
    expect(topOfPile([true, false, false], [true, false, false])).toBe(1)
    expect(topOfPile([true, false, true], [true, false, true])).toBe(1)
    expect(topOfPile([true, true], [true, true])).toBeNull()
  })
})

describe("storedAfterRebuild", () => {
  it("lays every revealed card in the tray on the way into the phone", () => {
    expect(storedAfterRebuild([true, false, true, false], [false, false, false, false], "phone")).toEqual([true, false, true, false])
    expect(storedAfterRebuild([true, true, false], [true, false, false], "phone")).toEqual([true, true, false])
  })

  it("stores nothing in a row", () => {
    expect(storedAfterRebuild([true, true, false], [true, true, false], "wide")).toEqual([false, false, false])
    expect(storedAfterRebuild([true, false], [true, false], "narrow")).toEqual([false, false])
  })
})

describe("zoomNeighbour", () => {
  it("steps to the previous or next filled slot, in booster order", () => {
    const stored = [true, true, true, true, true]
    expect(zoomNeighbour(stored, 2, -1)).toBe(1)
    expect(zoomNeighbour(stored, 2, 1)).toBe(3)
  })

  it("skips the empty slots between", () => {
    expect(zoomNeighbour([true, false, false, true, false], 0, 1)).toBe(3)
    expect(zoomNeighbour([true, false, false, true, false], 3, -1)).toBe(0)
  })

  it("has none before the first filled slot nor after the last", () => {
    expect(zoomNeighbour([true, true, true], 0, -1)).toBeNull()
    expect(zoomNeighbour([true, true, true], 2, 1)).toBeNull()
    expect(zoomNeighbour([false, true, true, false], 1, -1)).toBeNull()
    expect(zoomNeighbour([false, true, true, false], 2, 1)).toBeNull()
  })
})

describe("start", () => {
  it("seals the canister with a pack in reserve, the focus on the opening", () => {
    const state = startWith()
    expect(state).toMatchObject({ phase: "sealed", status: "sealed", answer: null, focus: "open", lockDepth: 0, layout: "wide" })
  })

  it("shows the reserve empty with none, the focus on the way back", () => {
    expect(startWith({ bank: bank(0) })).toMatchObject({ phase: "empty", status: "waiting", focus: "back" })
  })

  it("asks no focus on a Turbo preview", () => {
    expect(startWith({ preview: true }).focus).toBeNull()
  })

  it("deals a pack shown again every card revealed past the guard, complete", () => {
    const state = startWith({ opened: answerOf(["common", "rare"]), now: 5000 })
    expect(state).toMatchObject({ phase: "dealt", status: "complete", dealt: true, headShown: true, canisterAway: true })
    expect(state.revealed).toEqual([true, true])
    expect(state.revealedAt).toEqual([5000 - REVEAL_GUARD, 5000 - REVEAL_GUARD])
    expect(state.stored).toEqual([false, false])
    expect(state.celebration).toBeNull()
  })

  it("lays a pack shown again in the tray on the phone", () => {
    expect(startWith({ opened: answerOf(["common", "rare"]), layout: "phone" }).stored).toEqual([true, true])
  })

  it("brings back a remembered celebration still and already announced", () => {
    const state = startWith({ opened: answerOf(["epic"], [VALVE]), celebrationRemembered: true })
    expect(state.celebration).toHaveLength(1)
    expect(state).toMatchObject({ celebrationStill: true, celebrationAnnounced: true })
  })
})

describe("idle", () => {
  it("is idle with nothing running", () => {
    expect(idle(startWith())).toBe(true)
  })

  it("is not while an opening, a reveal, Reveal all, a store or a lock runs", () => {
    const state = dealt()
    expect(idle(openingStarted(startWith()))).toBe(false)
    expect(idle(revealStarted(state, 0, false))).toBe(false)
    expect(idle(revealAllStarted(state))).toBe(false)
    expect(idle({ ...state, storing: true })).toBe(false)
    expect(idle(lock(state))).toBe(false)
    expect(idle(arming(startWith(), "key"))).toBe(false)
  })
})

describe("lock, unlock, lockReleased, locked", () => {
  it("counts nested holds and is locked from the first", () => {
    const once = lock(startWith())
    const twice = lock(once)
    expect(locked(once)).toBe(true)
    expect(twice.lockDepth).toBe(2)
    expect(unlock(twice).lockDepth).toBe(1)
    expect(locked(unlock(once))).toBe(false)
  })

  it("does nothing when unlocked at zero", () => {
    const state = startWith()
    expect(unlock(state)).toBe(state)
    expect(lockReleased(state)).toBe(state)
  })

  it("releases every hold at once", () => {
    expect(lockReleased(lock(lock(startWith()))).lockDepth).toBe(0)
  })
})

describe("focusTarget, focusGiven", () => {
  it("resolves the card to act on: the first face-down card in a row", () => {
    const state = revealMarked(dealt(), 0, 0)
    expect(focusTarget({ ...state, focus: "card" })).toEqual({ card: 1 })
  })

  it("resolves the card on the phone to the top of the pile", () => {
    const state = cardStored(revealMarked(dealt(FIVE, { layout: "phone" }), 0, 0), 0)
    expect(focusTarget({ ...state, focus: "card" })).toEqual({ card: 1 })
  })

  it("resolves the card to what comes after once every card is shown", () => {
    const state = revealedAll(dealt())
    expect(focusTarget({ ...state, focus: "card" })).toBe("open")
    expect(focusTarget({ ...state, bank: bank(0), focus: "card" })).toBe("back")
  })

  it("keeps the opening, the way back and a tray slot as they are", () => {
    const state = startWith()
    expect(focusTarget(state)).toBe("open")
    expect(focusTarget({ ...state, focus: "back" })).toBe("back")
    expect(focusTarget({ ...state, focus: { slot: 2 } })).toEqual({ slot: 2 })
  })

  it("asks nothing once given", () => {
    const given = focusGiven(startWith())
    expect(focusTarget(given)).toBeNull()
    expect(focusGiven(given)).toBe(given)
  })
})

describe("bannerShown, bannerEnded", () => {
  const asked = { tier: "legendary" as const, large: true, line: "Golden Crown · 1998", reduced: false }

  it("shows a banner with a new key, ended only by its own key", () => {
    const first = bannerShown(dealt(), asked)
    const second = bannerShown(first, { ...asked, tier: "epic", large: false, line: null })
    expect(second.banner).toMatchObject({ key: first.bannerKey + 1, tier: "epic" })
    expect(bannerEnded(second, first.bannerKey)).toBe(second)
    expect(bannerEnded(second, second.bannerKey).banner).toBeNull()
  })

  it("shows none on the phone: the caption plate tells the tier", () => {
    const state = dealt(FIVE, { layout: "phone" })
    expect(bannerShown(state, asked)).toBe(state)
  })
})

describe("celebrate, shownCelebration, celebrationToAnnounce, celebrationSpoken", () => {
  it("celebrates the tiers the opening reached once the hand completes, not before", () => {
    const state = dealt(["epic"], {}, [VALVE])
    expect(state.celebration).toBeNull()
    const complete = revealEnded(revealMarked(revealStarted(state, 0, false), 0, 0), 0, false)
    expect(complete.status).toBe("complete")
    expect(shownCelebration(complete)).toHaveLength(1)
    expect(celebrationToAnnounce(complete)).toBe(complete.celebration)
  })

  it("shows the results only while no banner plays, announced once", () => {
    const pending = { ...dealt(["epic"], {}, [VALVE]), status: "complete" as const }
    const celebrated = celebrate(bannerShown(pending, { tier: "legendary", large: true, line: null, reduced: false }))
    expect(shownCelebration(celebrated)).toBeNull()
    expect(celebrationToAnnounce(celebrated)).toBeNull()
    const ended = bannerEnded(celebrated, celebrated.bannerKey)
    expect(shownCelebration(ended)).toHaveLength(1)
    const spoken = celebrationSpoken(ended)
    expect(celebrationToAnnounce(spoken)).toBeNull()
    expect(celebrationSpoken(spoken)).toBe(spoken)
  })

  it("celebrates nothing when no tier was reached or nothing waits", () => {
    const state = dealt()
    const after = celebrate(state)
    expect(after.celebration).toBeNull()
    expect(celebrate(after)).toBe(after)
  })

  it("is cleared by the next opening", () => {
    const complete = celebrate(revealedAll(dealt(["epic"], {}, [VALVE])))
    expect(complete.celebration).not.toBeNull()
    expect(openingStarted(complete).celebration).toBeNull()
  })
})

describe("bankChanged, bankFetched", () => {
  it("replaces the bank and counts the change", () => {
    const state = startWith()
    const changed = bankChanged(state, bank(3))
    expect(changed.bank.available).toBe(3)
    expect(changed.bankGeneration).toBe(state.bankGeneration + 1)
  })

  it("ignores a fetch answered after a newer bank change", () => {
    const state = startWith()
    const generation = state.bankGeneration
    const newer = bankChanged(state, bank(4))
    expect(bankFetched(newer, bank(9), generation)).toBe(newer)
  })

  it("moves a sealed or empty canister with the count, the reason cleared", () => {
    const empty = { ...startWith({ bank: bank(0) }), reason: "No capsule" }
    const fetched = bankFetched(empty, bank(1), empty.bankGeneration)
    expect(fetched).toMatchObject({ phase: "sealed", status: "sealed", reason: null })
    const emptied = bankFetched(startWith(), bank(0), 0)
    expect(emptied).toMatchObject({ phase: "empty", status: "waiting" })
  })

  it("leaves a dealt hand as it is", () => {
    const state = dealt()
    const fetched = bankFetched(state, bank(0), state.bankGeneration)
    expect(fetched).toMatchObject({ phase: "dealt", status: "inventory" })
    expect(fetched.bank.available).toBe(0)
  })
})

describe("countdownAtZero, bankFetchOwed, bankDue, owedBankTaken", () => {
  it("refreshes the page with no hand at rest", () => {
    expect(countdownAtZero(startWith())).toBe("page")
    expect(countdownAtZero(startWith({ bank: bank(0) }))).toBe("page")
  })

  it("fetches the bank with a hand put away, else owes the fetch", () => {
    expect(countdownAtZero(revealedAll(dealt()))).toBe("bank")
    expect(countdownAtZero(dealt())).toBe("owe")
    expect(countdownAtZero(lock(startWith()))).toBe("owe")
  })

  it("makes an owed fetch once nothing runs and the hand is put away", () => {
    const owed = bankFetchOwed(dealt())
    expect(bankFetchOwed(owed)).toBe(owed)
    expect(bankDue(owed)).toBe(false)
    expect(bankDue(revealedAll(owed))).toBe(true)
    expect(bankDue(lock(revealedAll(owed)))).toBe(false)
    const taken = owedBankTaken(revealedAll(owed))
    expect(bankDue(taken)).toBe(false)
    expect(owedBankTaken(taken)).toBe(taken)
  })
})

describe("canOpen, openingStarted", () => {
  it("opens a sealed canister, the reason and the celebration cleared", () => {
    const state = { ...startWith(), reason: "Too fast" }
    expect(canOpen(state)).toBe(true)
    expect(openingStarted(state)).toMatchObject({ opening: true, reason: null, celebration: null, celebrationPending: null })
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
})

describe("retracting, retracted", () => {
  it("hides the result head, then clears the hand and docks a new canister", () => {
    const hand = celebrate(revealedAll(dealt(["epic"], {}, [VALVE])))
    const sinking = retracting(hand)
    expect(sinking.headShown).toBe(false)
    expect(retracting(sinking)).toBe(sinking)
    const docked = retracted(sinking)
    expect(docked).toMatchObject({ answer: null, revealed: [], stored: [], dealt: false, armed: false, celebration: null, canisterAway: false, status: "sealed" })
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
    const refused = openingRefused(running(), { kind: "refused", code: "sign_in_required", message: "Sign in" }, "Failed")
    expect(refused).toMatchObject({ phase: "sealed", status: "sealed", armed: false, opening: false, reason: "Sign in", pendingKey: null, focus: "open" })
  })

  it("keeps the key after a throttle or a failure", () => {
    expect(openingRefused(running(), { kind: "refused", code: "throttled", message: "Slow down" }, "Failed").pendingKey).toBe("key-1")
    const failed = openingRefused(running(), { kind: "failed" }, "Failed")
    expect(failed).toMatchObject({ pendingKey: "key-1", reason: "Failed" })
  })

  it("empties the bank with no pack left, the focus on the way back", () => {
    const state = running()
    const refused = openingRefused(state, { kind: "refused", code: "no_pack_available", message: "None" }, "Failed")
    expect(refused).toMatchObject({ phase: "empty", status: "waiting", focus: "back" })
    expect(refused.bank).toMatchObject({ available: 0, reserveFull: false, nextPackSize: null })
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
    expect(answered.bank).toEqual({ available: 1, reserveFull: false, nextAvailableAt: null, serverTime: answer.serverTime, nextPackSize: 5 })
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
    expect(openingEnded(onTable)).toMatchObject({ canisterAway: true, status: "inventory", phase: "dealt", opening: false, focus: "card" })
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
    expect(throughReveal(revealMarked(dealt(["common", "rare"], { layout: "phone" }), 0, 0), 1).status).toBe("inventory")
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

describe("layoutAsked, layoutApplied", () => {
  it("keeps the layout the width asks for until the island is idle", () => {
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
    expect(controls(hand)).toMatchObject({ open: "next", openDisabled: true, revealAllDisabled: false, revealedCount: 1, hint: { kind: "remaining", count: 4 } })
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
