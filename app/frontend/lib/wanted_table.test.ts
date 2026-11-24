import { describe, expect, it } from "vitest"
import {
  choose,
  pending,
  prefill,
  setDuration,
  setStart,
  start,
  totals,
  type Picked,
  type WantedLine,
} from "./wanted_table"

const line = (ref: string, over: Partial<WantedLine> = {}): WantedLine => ({
  ref,
  title: ref.toUpperCase(),
  copies: 1,
  value: 50,
  minimum: 78,
  stamp: 20,
  average: null,
  orders: [],
  direct: true,
  changed: false,
  ...over,
})

const blank: Picked = { choice: null, start: "", duration: "24" }

const draw = (lines: WantedLine[], capLeft = 12_000, picked: Record<string, Picked> = {}, available = 1_000_000) =>
  start(lines, Object.fromEntries(lines.map((each) => [each.ref, picked[each.ref] ?? blank])), {
    capLeft,
    basisPoints: 1_000,
    available,
  })

describe("the Prefill rule of a line above Uncommon", () => {
  const rare = (ref: string, over: Partial<WantedLine> = {}) => line(ref, { direct: false, ...over })

  it("opens its auction at the lowest eligible order's price so every order converts", () => {
    const state = prefill(draw([rare("a", { orders: [400, 350], average: 1_000 })]))
    expect(state.picked.a).toEqual({ choice: "auction", start: "350", duration: "24" })
  })

  it("opens at the average with no order, else at the minimum", () => {
    expect(prefill(draw([rare("a", { average: 1_000 })])).picked.a?.start).toBe("1000")
    expect(prefill(draw([rare("a")])).picked.a?.start).toBe("78")
  })

  it("entrusts when its stamps cannot be paid and the copies fit under the cap", () => {
    expect(prefill(draw([rare("a", { stamp: 20 })], 12_000, {}, 19)).picked.a?.choice).toBe("entrust")
    expect(prefill(draw([rare("a", { stamp: 20 })], 10, {}, 19)).picked.a?.choice).toBe("auction")
  })

  it("counts the proceeds of the lines before it when it checks its stamps", () => {
    const lines = [line("a", { orders: [900], average: 1_000 }), rare("b", { stamp: 20 })]
    expect(prefill(draw(lines, 12_000, {}, 0)).picked.b?.choice).toBe("auction")
  })

  it("counts the stamps of an auction before it and the copies entrusted before it when it checks its stamps", () => {
    const stamps = [rare("a", { stamp: 20 }), rare("b", { stamp: 20 })]
    expect(prefill(draw(stamps, 12_000, {}, 30)).picked.b?.choice).toBe("entrust")
    const entrusted = [line("a", { value: 50 }), rare("b", { stamp: 20 })]
    const picked = { a: { choice: "entrust", start: "", duration: "24" } satisfies Picked }
    expect(prefill(draw(entrusted, 12_000, picked, 0)).picked.b?.choice).toBe("auction")
  })

  it("never chooses an order", () => {
    const state = draw([rare("a", { orders: [400] })])
    expect(choose(state, "a", "order")).toBe(state)
  })
})

describe("the Prefill rule", () => {
  it("sells to an order at 90% of the average price or more", () => {
    const state = prefill(draw([line("a", { orders: [900], average: 1_000 })]))
    expect(state.picked.a).toEqual({ choice: "order", start: "", duration: "24" })
  })

  it("opens an auction at the average when the order is far below it", () => {
    const state = prefill(draw([line("a", { orders: [899], average: 1_000 })]))
    expect(state.picked.a).toEqual({ choice: "auction", start: "1000", duration: "24" })
  })

  it("opens an auction at the order's price with no average, never under the minimum", () => {
    expect(prefill(draw([line("a", { orders: [300] })])).picked.a?.start).toBe("300")
    expect(prefill(draw([line("a", { orders: [40] })])).picked.a?.start).toBe("78")
  })

  it("entrusts a line with no order while it fits the cap left, walked in table order", () => {
    const lines = [line("a", { copies: 2 }), line("b", { average: 200 }), line("c", { value: 40 })]
    const state = prefill(draw(lines, 140))
    expect(state.lines.map((each) => state.picked[each.ref]?.choice)).toEqual(["entrust", "auction", "entrust"])
    expect(state.picked.b?.start).toBe("200")
  })

  it("starts an auction at the minimum for a line over the cap with no average", () => {
    expect(prefill(draw([line("a")], 10)).picked.a).toEqual({ choice: "auction", start: "78", duration: "24" })
  })

  it("keeps a posted choice and a typed price, and redraws a changed line", () => {
    const posted = {
      a: { choice: "entrust", start: "", duration: "24" },
      b: { choice: "order", start: "120", duration: "72" },
    } as const
    const state = prefill(
      draw([line("a", { orders: [900] }), line("b", { changed: true, orders: [], average: 500 })], 12_000, posted),
    )
    expect(state.picked.a?.choice).toBe("entrust")
    expect(state.picked.b).toEqual({ choice: "entrust", start: "120", duration: "72" })
  })
})

describe("the dock's totals", () => {
  it("adds the sales net of the commission and the copies entrusted under the cap", () => {
    const lines = [
      line("a", { copies: 3, orders: [900, 800] }),
      line("b", { copies: 2, stamp: 10 }),
      line("c", { copies: 2, value: 100 }),
    ]
    const state = prefill(draw(lines, 150))
    const chosen = setStart(choose(choose(choose(state, "a", "order"), "b", "auction"), "c", "entrust"), "b", "1 000")
    const sum = totals(chosen)
    expect(sum).toMatchObject({ sales: 2, salesAmount: 810 + 720, entrusted: 2, entrustedAmount: 150, now: 1_680 })
    expect(sum).toMatchObject({ listed: 2, listedAmount: 1_800, stamps: 20, over: 1, overTitles: ["C"] })
    expect(sum.lines).toEqual({
      a: { amount: 1_580, when: "now" },
      b: { amount: 1_800, when: "start" },
      c: { amount: 100, when: "now" },
    })
  })

  it("counts no proceeds for an auction without a valid start", () => {
    const state = choose(prefill(draw([line("a")])), "a", "auction")
    expect(totals(setStart(state, "a", "abc"))).toMatchObject({ listed: 1, listedAmount: 0, stamps: 20 })
  })

  it("prices entrusting everything at what fits under the cap", () => {
    const state = prefill(draw([line("a", { copies: 2, value: 100 }), line("b", { value: 50 })], 160))
    expect(totals(state).allEntrust).toBe(150)
  })
})

describe("the choices", () => {
  it("refuses the order for a line with none drawn", () => {
    const state = prefill(draw([line("a")]))
    expect(choose(state, "a", "order")).toBe(state)
  })

  it("is pending once a choice, a price or a duration moves from the draw", () => {
    const state = prefill(draw([line("a", { orders: [900], average: 900 })]))
    expect(pending(state)).toBe(false)
    expect(pending(choose(state, "a", "auction"))).toBe(true)
    expect(pending(setStart(state, "a", "5"))).toBe(true)
    expect(pending(setDuration(state, "a", "72"))).toBe(true)
    expect(pending(choose(choose(state, "a", "auction"), "a", "order"))).toBe(false)
  })
})
