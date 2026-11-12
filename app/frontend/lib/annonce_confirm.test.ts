import unusualMaximumsJson from "../../../test/fixtures/files/unusual_maximums.json?raw"
import { describe, expect, it } from "vitest"
import { edit, start, submit, type Gate, type Terms } from "./annonce"
import { ask, consented, gate, grant, multipleOf, revoke } from "./annonce_confirm"

type Row = { price: number; maximum: number; multiple: number; gate: Gate }

const rows: Row[] = JSON.parse(unusualMaximumsJson)

const terms = (overrides: Partial<Terms> = {}): Terms => ({
  minimum: 20_000,
  available: 1_000_000,
  ownMaximum: null,
  price: 20_000,
  unusualMultiple: 3,
  ...overrides,
})

const typed = (text: string, overrides: Partial<Terms> = {}) => edit(start(terms(overrides)), text)

describe("the gate", () => {
  it.each(rows)("reads $gate for a maximum of $maximum on $price", (row) => {
    const state = typed(String(row.maximum), { price: row.price, unusualMultiple: row.multiple })
    expect(gate(state)).toBe(row.gate)
  })

  it("lets an invalid or empty text through to the server", () => {
    expect(gate(typed(""))).toBe("none")
    expect(gate(typed("3x0"))).toBe("none")
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
  it("is bound to the text it was asked for", () => {
    const asked = ask(typed("60000"))
    const granted = grant(asked)

    expect(asked.pending).toBe(true)
    expect(granted.pending).toBe(false)
    expect(consented(granted)).toBe(true)
  })

  it("is revoked by a text change", () => {
    const granted = grant(ask(typed("60000")))

    expect(consented(edit(granted, "70000"))).toBe(false)
  })

  it("is revoked explicitly and by a submission", () => {
    const granted = grant(ask(typed("60000")))

    expect(consented(revoke(granted))).toBe(false)
    expect(consented(submit(granted)!)).toBe(false)
  })

  it("grants nothing without a question", () => {
    const state = typed("60000")
    expect(grant(state)).toBe(state)
    expect(revoke(state)).toBe(state)
  })
})
