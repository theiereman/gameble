import bidCommitmentsJson from "../../../test/fixtures/files/bid_commitments.json?raw"
import { describe, expect, it } from "vitest"
import { buttonKind, commitment, edit, parse, posted, retermed, start, submit, submitted, type Terms } from "./annonce"

type Row = { maximum: number; own_maximum: number | null; needed: number }

const rows: Row[] = JSON.parse(bidCommitmentsJson)

const terms = (overrides: Partial<Terms> = {}): Terms => ({
  minimum: 20_000,
  available: 100_000,
  ownMaximum: null,
  price: 20_000,
  unusualMultiple: 3,
  ...overrides,
})

describe("parse", () => {
  it("reads plain digits or digits grouped by threes", () => {
    expect(parse("30000")).toBe(30_000)
    expect(parse(" 30 000 ")).toBe(30_000)
    expect(parse("30\u00A0000")).toBe(30_000)
    expect(parse("30\u202F000")).toBe(30_000)
    expect(parse("8,000,000")).toBe(8_000_000)
  })

  it("refuses anything else", () => {
    for (const text of ["", " ", "3x0", "3,00", "12,5", "3.5", "3 0", "1,000 000", "-30", "0", "00", "1e3"])
      expect(parse(text)).toBeNull()
  })

  it("refuses an amount that is not a safe integer", () => {
    expect(parse("9007199254740993")).toBeNull()
    expect(parse("9007199254740991")).toBe(9_007_199_254_740_991)
  })
})

describe("commitment", () => {
  it.each(rows)("matches the server's needed amount for $maximum", ({ maximum, own_maximum, needed }) => {
    const state = start(terms({ ownMaximum: own_maximum }))
    expect(commitment(state, maximum)).toBe(needed)
  })
})

describe("the button kind", () => {
  it("is idle until the text is a valid amount", () => {
    expect(buttonKind(start(terms()))).toBe("idle")
    expect(buttonKind(edit(start(terms()), "3x0"))).toBe("idle")
  })

  it("bids for a valid amount and raises for a leader", () => {
    expect(buttonKind(edit(start(terms()), "30000"))).toBe("bid")
    expect(buttonKind(edit(start(terms({ ownMaximum: 30_000 })), "35000"))).toBe("raise")
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

describe("retermed", () => {
  it("takes the terms the page redrew and keeps the typed text", () => {
    const typed = edit(start(terms()), "30000")
    const next = retermed(typed, terms({ minimum: 31_500, price: 30_000 }), false)

    expect(next.text).toBe("30000")
    expect(next.terms.minimum).toBe(31_500)
    expect(next.terms.price).toBe(30_000)
  })

  it("takes the answered flag from the page, so a redrawn foot without its panel is never left hidden", () => {
    const answered = start(terms(), true)

    expect(retermed(answered, terms(), false).answered).toBe(false)
  })
})
