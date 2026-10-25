import { describe, expect, it } from "vitest"
import { keepsFrame } from "./screen_change"

const desktop = { phone: false }
const phone = { phone: true }
const TRADE = "/en/trades/2bGzqYbBn9rK3mXcWqTnPd4H"
const OTHER_TRADE = "/en/trades/7hFkLmNpQrStUvWxYz1A2B3C"

describe("keepsFrame", () => {
  it("keeps the frame on a visit to the page shown", () => {
    expect(keepsFrame("/en/library", "/en/library", desktop)).toBe(true)
    expect(keepsFrame("/fr", "/fr", phone)).toBe(true)
  })

  it("changes the screen between two other pages", () => {
    expect(keepsFrame("/en", "/en/library", desktop)).toBe(false)
    expect(keepsFrame("/en/library/cards", "/en/cards/portal", desktop)).toBe(false)
    expect(keepsFrame("/en/library", "/en/library/theme/horror", phone)).toBe(false)
  })

  it("keeps the frame between the steps of Trades on a desktop", () => {
    expect(keepsFrame("/en/trades", TRADE, desktop)).toBe(true)
    expect(keepsFrame(TRADE, OTHER_TRADE, desktop)).toBe(true)
    expect(keepsFrame(TRADE, `${TRADE}/counter`, desktop)).toBe(true)
    expect(keepsFrame("/fr/trades/new", "/fr/trades", desktop)).toBe(true)
    expect(keepsFrame("/en/trades/new", TRADE, desktop)).toBe(true)
  })

  it("on a phone, changes the screen between the list and a board, not between two boards", () => {
    expect(keepsFrame("/en/trades", TRADE, phone)).toBe(false)
    expect(keepsFrame(TRADE, "/en/trades", phone)).toBe(false)
    expect(keepsFrame(TRADE, `${TRADE}/counter`, phone)).toBe(true)
    expect(keepsFrame("/en/trades/new", TRADE, phone)).toBe(true)
  })

  it("changes the screen into and out of Trades", () => {
    expect(keepsFrame("/en", "/en/trades", desktop)).toBe(false)
    expect(keepsFrame(TRADE, "/en/friends", desktop)).toBe(false)
    expect(keepsFrame("/en/tradesman", "/en/trades", desktop)).toBe(false)
  })
})
