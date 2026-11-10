import { readFileSync } from "node:fs"
import { describe, expect, it } from "vitest"
import {
  buttonKind,
  commitment,
  edit,
  parse,
  posted,
  reachesBuyNow,
  start,
  submit,
  submitted,
  type Terms,
} from "./annonce"

type Row = { maximum: number; own_maximum: number | null; buy_now: number | null; needed: number }

const rows: Row[] = JSON.parse(readFileSync("test/fixtures/files/bid_commitments.json", "utf8"))

const terms = (overrides: Partial<Terms> = {}): Terms => ({
  minimum: 20_000,
  available: 100_000,
  buyNow: null,
  ownMaximum: null,
  price: 20_000,
  unusualMultiple: 3,
  ...overrides,
})

describe("parse", () => {
  it("reads digits only, spaces removed", () => {
    expect(parse("30000")).toBe(30_000)
    expect(parse(" 30 000 ")).toBe(30_000)
    expect(parse("30 000")).toBe(30_000)
    expect(parse("30 000")).toBe(30_000)
  })

  it("refuses anything else", () => {
    for (const text of ["", " ", "3x0", "3,000", "3.5", "-30", "0", "00", "1e3"]) expect(parse(text)).toBeNull()
  })

  it("refuses an amount that is not a safe integer", () => {
    expect(parse("9007199254740993")).toBeNull()
    expect(parse("9007199254740991")).toBe(9_007_199_254_740_991)
  })
})

describe("commitment", () => {
  it.each(rows)("matches the server's needed amount for $maximum", ({ maximum, own_maximum, buy_now, needed }) => {
    const state = start(terms({ ownMaximum: own_maximum, buyNow: buy_now }))
    expect(commitment(state, maximum)).toBe(needed)
  })
})

describe("the button kind", () => {
  it("is idle until the text is a valid amount", () => {
    expect(buttonKind(start(terms()))).toBe("idle")
    expect(buttonKind(edit(start(terms()), "3x0"))).toBe("idle")
  })

  it("bids for a valid amount, raises for a leader, buys at the buy-now", () => {
    expect(buttonKind(edit(start(terms()), "30000"))).toBe("bid")
    expect(buttonKind(edit(start(terms({ ownMaximum: 30_000 })), "35000"))).toBe("raise")
    expect(buttonKind(edit(start(terms({ buyNow: 60_000 })), "60000"))).toBe("buy")
    expect(buttonKind(edit(start(terms({ buyNow: 60_000, ownMaximum: 30_000 })), "70000"))).toBe("buy")
    expect(buttonKind(edit(start(terms({ buyNow: 60_000 })), "59999"))).toBe("bid")
  })

  it("knows when an amount reaches the buy-now", () => {
    expect(reachesBuyNow(terms(), 1_000_000)).toBe(false)
    expect(reachesBuyNow(terms({ buyNow: 60_000 }), 60_000)).toBe(true)
  })
})

describe("editing", () => {
  it("shows the foot again after an answer", () => {
    const answered = start(terms(), true)
    expect(edit(answered, "1").answered).toBe(false)
  })

  it("keeps the same state for the same text", () => {
    const state = edit(start(terms()), "30000")
    expect(edit(state, "30000")).toBe(state)
  })
})

describe("the single submission", () => {
  it("lets one submit through and refuses the second until released", () => {
    const first = submit(start(terms()))
    expect(first?.submitting).toBe(true)
    expect(submit(first!)).toBeNull()
    expect(submit(submitted(first!))).not.toBeNull()
  })
})

describe("the live sentence", () => {
  it("remembers what was posted", () => {
    const state = posted(start(terms()), "one")
    expect(state.posted).toBe("one")
    expect(posted(state, "one")).toBe(state)
  })
})
