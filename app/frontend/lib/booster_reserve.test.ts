import { describe, expect, it } from "vitest"
import { bank, startWith } from "./booster_fixtures"
import { bankFetched, canOpen, reserveSelected, reservesUnlocked } from "./booster"

const BOTH = bank(3, { special: 2, openable: 5 })

describe("reserveSelected", () => {
  it("selects a reserve that holds capsules", () => {
    const state = reserveSelected(startWith({ bank: BOTH }), "special")

    expect(state.reserve).toBe("special")
    expect(state.phase).toBe("sealed")
    expect(canOpen(state)).toBe(true)
  })

  it("refuses an empty reserve", () => {
    const state = startWith({ bank: bank(3) })

    expect(reserveSelected(state, "special")).toBe(state)
  })

  it("refuses while an opening is under way", () => {
    const state = { ...startWith({ bank: BOTH }), opening: true }

    expect(reserveSelected(state, "special")).toBe(state)
  })

  it("leaves the empty screen for the other reserve once it holds a capsule", () => {
    const empty = startWith({ bank: bank(0, { special: 1, openable: 1 }), reserve: "standard" })

    expect(empty.phase).toBe("empty")
    expect(reserveSelected(empty, "special").phase).toBe("sealed")
  })
})

describe("a reserve unlocking on the page", () => {
  it("names the reserves that went from none to some", () => {
    expect(reservesUnlocked(bank(0), bank(1))).toEqual(["standard"])
    expect(reservesUnlocked(bank(2), bank(2, { special: 1, openable: 3 }))).toEqual(["special"])
    expect(reservesUnlocked(bank(2), bank(3))).toEqual([])
  })

  it("keeps the selection and the empty screen when the other reserve unlocks", () => {
    const state = startWith({ bank: bank(0), reserve: "standard" })
    const fetched = bankFetched(state, bank(0, { special: 1, openable: 1 }), state.bankGeneration)

    expect(fetched.reserve).toBe("standard")
    expect(fetched.phase).toBe("empty")
  })

  it("opens the selected reserve again once its own capsule arrives", () => {
    const state = startWith({ bank: bank(0), reserve: "standard" })
    const fetched = bankFetched(state, bank(1), state.bankGeneration)

    expect(fetched.phase).toBe("sealed")
  })
})
