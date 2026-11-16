import { describe, expect, it } from "vitest"
import { acceptsView, moveNumberFrom, startDuel, viewShown } from "./duel"

describe("acceptsView", () => {
  it("takes only a view strictly newer than the one shown", () => {
    const state = startDuel(4)

    expect(acceptsView(state, 5)).toBe(true)
    expect(acceptsView(state, 4)).toBe(false)
    expect(acceptsView(state, 3)).toBe(false)
  })

  it("compares against the last view shown", () => {
    const state = viewShown(startDuel(4), 7)

    expect(state.moveNumber).toBe(7)
    expect(acceptsView(state, 7)).toBe(false)
    expect(acceptsView(state, 8)).toBe(true)
  })
})

describe("moveNumberFrom", () => {
  it("reads a non-negative whole number", () => {
    expect(moveNumberFrom("0")).toBe(0)
    expect(moveNumberFrom("21")).toBe(21)
  })

  it("reads nothing else", () => {
    expect(moveNumberFrom("-1")).toBeNull()
    expect(moveNumberFrom("1.5")).toBeNull()
    expect(moveNumberFrom("")).toBeNull()
    expect(moveNumberFrom("2a")).toBeNull()
    expect(moveNumberFrom(null)).toBeNull()
    expect(moveNumberFrom(undefined)).toBeNull()
  })
})
