import { describe, expect, it } from "vitest"
import type { OpeningSetTier } from "./opening"
import { arming, cardStored, openingStarted, revealAllStarted, revealEnded, revealMarked, revealStarted } from "./booster_opening"
import { bankChanged, bankDue, bankFetchOwed, bankFetched, bannerEnded, bannerShown, celebrate, celebrationSpoken, celebrationStepped, celebrationToAnnounce, countdownAtZero, focusGiven, focusTarget, idle, lock, lockReleased, locked, owedBankTaken, shownCelebration, shownResult, start, unlock } from "./booster_state"
import { REVEAL_GUARD } from "./booster_types"
import { layoutApplied, layoutAsked } from "./booster_view"
import { FIVE, VALVE, answerOf, bank, dealt, revealedAll, startWith } from "./booster_fixtures"

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

describe("celebrationStepped, shownResult", () => {
  const PORTAL: OpeningSetTier = { ...VALVE, kind: "genre", key: "shooter", name: "Shooter", tier: "silver", required: 2, total: 9, held: 2 }

  it("steps through the results one at a time, back to the first after the last", () => {
    const complete = celebrate(revealedAll(dealt(["epic", "common"], {}, [VALVE, PORTAL])))
    expect(shownResult(complete)).toBe(0)
    const once = celebrationStepped(complete)
    expect(once.celebrationSteps).toBe(1)
    expect(shownResult(once)).toBe(1)
    expect(shownResult(celebrationStepped(once))).toBe(0)
  })

  it("does not step a single result or no celebration, and starts again at the first with a new celebration or opening", () => {
    const single = celebrate(revealedAll(dealt(["epic"], {}, [VALVE])))
    expect(celebrationStepped(single)).toBe(single)
    expect(celebrationStepped(dealt())).toEqual(dealt())
    expect(shownResult(dealt())).toBe(0)
    const stepped = celebrationStepped(celebrate(revealedAll(dealt(["epic", "common"], {}, [VALVE, PORTAL]))))
    expect(openingStarted({ ...stepped, status: "complete" }).celebrationSteps).toBe(0)
  })

  it("starts again at the first result when a new celebration comes and when a layout is applied", () => {
    const stepped = celebrationStepped(celebrate(revealedAll(dealt(["epic", "common"], {}, [VALVE, PORTAL]))))
    expect(stepped.celebrationSteps).toBe(1)
    expect(celebrate({ ...stepped, celebrationPending: [VALVE, PORTAL] }).celebrationSteps).toBe(0)
    const rebuilt = layoutApplied(layoutAsked(stepped, stepped.layout === "phone" ? "wide" : "phone"), false)
    expect(rebuilt.layout).not.toBe(stepped.layout)
    expect(rebuilt.celebrationSteps).toBe(0)
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
