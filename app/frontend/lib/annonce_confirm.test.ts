import unusualMaximumsJson from "../../../test/fixtures/files/unusual_maximums.json?raw"
import { describe, expect, it } from "vitest"
import { edit, start, submit, type Gate, type Terms } from "./annonce"
import { ask, consented, gate, grant, multipleOf, revoke } from "./annonce_confirm"

type Row = { price: number; maximum: number; multiple: number; buy_now: number | null; gate: Gate }

const rows: Row[] = JSON.parse(unusualMaximumsJson)

const terms = (overrides: Partial<Terms> = {}): Terms => ({
  minimum: 20_000,
  available: 1_000_000,
  buyNow: null,
  ownMaximum: null,
  price: 20_000,
  unusualMultiple: 3,
  ...overrides,
})

const typed = (text: string, overrides: Partial<Terms> = {}) => edit(start(terms(overrides)), text)

describe("the gate", () => {
  it.each(rows)("reads $gate for a maximum of $maximum on $price", (row) => {
    const state = typed(String(row.maximum), { price: row.price, unusualMultiple: row.multiple, buyNow: row.buy_now })
    expect(gate(state, false)).toBe(row.gate)
  })

  it("lets the buy-now button through to the buy-now confirmation whatever is typed", () => {
    expect(gate(typed(""), true)).toBe("buy_now")
    expect(gate(typed("3x0"), true)).toBe("buy_now")
    expect(gate(typed("1", { buyNow: 50_000 }), true)).toBe("buy_now")
  })

  it("lets an invalid or empty text through to the server", () => {
    expect(gate(typed(""), false)).toBe("none")
    expect(gate(typed("3x0"), false)).toBe("none")
  })

  it("gives the buy-now confirmation precedence over the unusual one", () => {
    expect(gate(typed("600000", { buyNow: 100_000 }), false)).toBe("buy_now")
  })
})

describe("the multiple shown", () => {
  it("truncates", () => {
    expect(multipleOf(79_999, 20_000)).toBe(3)
    expect(multipleOf(60_000, 20_000)).toBe(3)
    expect(multipleOf(199_999, 20_000)).toBe(9)
  })
})

describe("consent", () => {
  it("is bound to a submitter and a text", () => {
    const asked = ask(typed("60000"), "unusual", "bid")
    const granted = grant(asked)

    expect(granted.pending).toBeNull()
    expect(consented(granted, "bid")).toBe(true)
    expect(consented(granted, "buy_now")).toBe(false)
  })

  it("is revoked by a text change", () => {
    const granted = grant(ask(typed("60000"), "unusual", "bid"))

    expect(consented(edit(granted, "70000"), "bid")).toBe(false)
  })

  it("is revoked explicitly and by a submission", () => {
    const granted = grant(ask(typed("60000"), "unusual", "bid"))

    expect(consented(revoke(granted), "bid")).toBe(false)
    expect(consented(submit(granted)!, "bid")).toBe(false)
  })

  it("grants nothing without a question", () => {
    const state = typed("60000")
    expect(grant(state)).toBe(state)
    expect(revoke(state)).toBe(state)
  })
})
