import listingAmountsJson from "../../../test/fixtures/files/listing_amounts.json?raw"
import { describe, expect, it } from "vitest"
import {
  back,
  choose,
  commission,
  know,
  layoutAsked,
  lines,
  opening,
  received,
  refusal,
  setDuration,
  setStart,
  start,
  validate,
  type Edition,
  type ListingState,
} from "./listing_form"

type Row = { price: string; basisPoints: number; commission: string; received: string }

const rows: Row[] = JSON.parse(listingAmountsJson)

const rare: Edition = {
  ref: "alpha:1",
  title: "Alpha",
  rarity: "rare",
  rarityName: "rare",
  season: 1,
  free: 2,
  minimum: 1_000,
  stamp: 500,
  order: null,
  orders: [],
}
const common: Edition = { ...rare, ref: "beta:1", title: "Beta", rarity: "common", minimum: 100, stamp: 50 }

const typed = { start: "", duration: "24" }

function chosenState(values: Partial<typeof typed> = {}): ListingState {
  return start([rare, common], 1_000, { ...typed, ...values }, "alpha:1", "wide")
}

describe("commission and received", () => {
  it.each(rows)("$price at $basisPoints basis points", ({ price, basisPoints, commission: fee, received: net }) => {
    expect(commission(BigInt(price), basisPoints)).toBe(BigInt(fee))
    expect(received(BigInt(price), basisPoints)).toBe(BigInt(net))
  })
})

describe("choosing", () => {
  it("starts on the first step with nothing chosen", () => {
    const state = start([rare, common], 1_000, typed, null, "wide")

    expect(state.chosen).toBeNull()
    expect(state.step).toBe(1)
  })

  it("starts on the second step when an edition is chosen", () => {
    expect(chosenState().step).toBe(2)
  })

  it("ignores a ref that is not an edition of the grid", () => {
    expect(start([rare], 1_000, typed, "gone:1", "wide").chosen).toBeNull()
    const state = start([rare], 1_000, typed, null, "wide")
    expect(choose(state, "gone:1")).toBe(state)
  })

  it("moves to the second step when an edition is chosen and back to the first", () => {
    const chosen = choose(start([rare, common], 1_000, typed, null, "phone"), "beta:1")

    expect(chosen).toMatchObject({ chosen: "beta:1", step: 2 })
    expect(back(chosen).step).toBe(1)
    expect(back(back(chosen))).toEqual(back(chosen))
  })

  it("keeps what was typed when another edition is chosen", () => {
    const state = choose(chosenState({ start: "1500" }), "beta:1")

    expect(state.start).toBe("1500")
  })
})

describe("orders turning into bids", () => {
  const ordered: Edition = { ...rare, minimum: 100, orders: [400, 350, 280] }
  const withOrders = (values: Partial<typeof typed> = {}): ListingState =>
    start([ordered, common], 1_000, { ...typed, ...values }, null, "wide", undefined, 500)

  it("prefills the start at the lowest order's price when the seller has not typed", () => {
    expect(choose(withOrders(), "alpha:1", "en").start).toBe("280")
    expect(choose(withOrders(), "alpha:1", "fr").start).toBe("280")
    expect(
      choose(start([{ ...ordered, orders: [1_500, 1_200] }], 1_000, typed, null, "wide"), "alpha:1", "en").start,
    ).toBe("1,200")
  })

  it("keeps what the seller typed", () => {
    expect(choose(withOrders({ start: "1500" }), "alpha:1").start).toBe("1500")
  })

  it("raises the prefill to the edition's minimum when the lowest order is under it", () => {
    const under = { ...ordered, minimum: 300, orders: [400, 250] }

    expect(choose(start([under], 1_000, typed, null, "wide", undefined, 500), "alpha:1", "en").start).toBe("300")
  })

  it("replaces a prefill that the next edition does not share", () => {
    const prefilled = choose(withOrders(), "alpha:1")

    expect(choose(prefilled, "beta:1").start).toBe("")
  })

  it("opens at the runner-up raised by an increment, capped by the best, over the orders at or above the start", () => {
    const state = setStart(choose(withOrders(), "alpha:1"), "300")

    expect(opening(state)).toEqual({ price: 368, left: [280] })
  })

  it("opens at the start itself when one order reaches it", () => {
    expect(opening(setStart(choose(withOrders(), "alpha:1"), "400"))).toEqual({ price: 400, left: [350, 280] })
    expect(opening(setStart(choose(withOrders(), "alpha:1"), "350"))).toEqual({ price: 368, left: [280] })
  })

  it("caps the price at the best order when the increment overshoots it", () => {
    const close = { ...ordered, orders: [360, 350] }
    const state = start([close], 1_000, { ...typed, start: "300" }, "alpha:1", "wide", undefined, 500)

    expect(opening(state)).toEqual({ price: 360, left: [] })
  })

  it("leaves every order open and names no price above them all", () => {
    expect(opening(setStart(choose(withOrders(), "alpha:1"), "500"))).toEqual({ price: null, left: [400, 350, 280] })
  })

  it("says nothing without orders or without a valid start", () => {
    expect(opening(chosenState({ start: "300" }))).toBeNull()
    expect(opening(setStart(choose(withOrders(), "alpha:1"), "abc"))).toBeNull()
    expect(opening(withOrders())).toBeNull()
  })
})

describe("transitions", () => {
  it("each edit clears the refusal shown", () => {
    const shown = validate(chosenState({ start: "10" }))
    expect(shown.shown).not.toBeNull()

    expect(setStart(shown, "1000").shown).toBeNull()
  })

  it("keeps the same state for a duration that does not change", () => {
    const state = chosenState()

    expect(setDuration(state, "24")).toBe(state)
    expect(setDuration(state, "72").duration).toBe("72")
  })

  it("keeps the same state for a layout that does not change", () => {
    const state = chosenState()

    expect(layoutAsked(state, "wide")).toBe(state)
    expect(layoutAsked(state, "phone").layout).toBe("phone")
  })
})

describe("refusal", () => {
  it("has none before an edition is chosen", () => {
    expect(refusal(start([rare], 1_000, typed, null, "wide"))).toBeNull()
  })

  it.each(["", "0", "12x", "1.5", "12,5", "1,00", "-4"])("refuses the start %j as not a price", (value) => {
    expect(refusal(chosenState({ start: value }))).toEqual({ field: "start", code: "invalidPrice" })
  })

  it("refuses a start under the minimum, and accepts the minimum itself", () => {
    expect(refusal(chosenState({ start: "999" }))).toEqual({ field: "start", code: "belowMinimum" })
    expect(refusal(chosenState({ start: "1000" }))).toBeNull()
  })

  it.each(["1,000", "1 000", "1\u00A0000", "1\u202F000"])("reads the grouped start %j as a price", (value) => {
    expect(refusal(chosenState({ start: value }))).toBeNull()
  })

  it("shows the refusal only once validated", () => {
    const state = chosenState({ start: "5" })

    expect(state.shown).toBeNull()
    expect(validate(state).shown).toEqual({ field: "start", code: "belowMinimum" })
  })
})

describe("lines", () => {
  it("has none before an edition is chosen", () => {
    expect(lines(start([rare], 1_000, typed, null, "wide"))).toBeNull()
  })

  it("gives the stamp, the commission and the amount received at the start", () => {
    expect(lines(chosenState({ start: "1300" }))).toEqual({ stamp: 500, commission: 130, received: 1_170 })
    expect(lines(chosenState({ start: "1,300" }))).toEqual({ stamp: 500, commission: 130, received: 1_170 })
  })

  it("gives the stamp alone while the start is empty or not digits", () => {
    expect(lines(chosenState())).toEqual({ stamp: 500, commission: null, received: null })
    expect(lines(chosenState({ start: "12x" }))).toEqual({ stamp: 500, commission: null, received: null })
  })

  it("gives no figure beyond the safe integers", () => {
    expect(lines(chosenState({ start: String(Number.MAX_SAFE_INTEGER) }))?.received).toBe(
      Number.MAX_SAFE_INTEGER - 900_719_925_474_099,
    )
    expect(lines(chosenState({ start: String(BigInt(Number.MAX_SAFE_INTEGER) + 1n) }))).toEqual({
      stamp: 500,
      commission: null,
      received: null,
    })
  })
})

describe("the loaded cells", () => {
  it("keeps the chosen edition and its amounts when a filter reload takes its cell away", () => {
    const reloaded = know(chosenState({ start: "1500" }), [], ["beta:1"])
    expect(reloaded).toMatchObject({ chosen: "alpha:1", step: 2, loaded: ["beta:1"] })
    expect(lines(reloaded)?.stamp).toBe(500)
  })

  it("lets a cell of a page appended later be chosen", () => {
    const later: Edition = { ...common, ref: "gamma:1" }
    const state = start([rare], 1_000, typed, null, "wide")
    expect(choose(state, "gamma:1")).toBe(state)
    expect(choose(know(state, [later], ["alpha:1", "gamma:1"]), "gamma:1").chosen).toBe("gamma:1")
  })
})
