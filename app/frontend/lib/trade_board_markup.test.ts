import { describe, expect, it } from "vitest"
import { cardFrom, lineFrom } from "./trade_board_markup"

describe("cardFrom", () => {
  it("reads a card's data attributes as numbers", () => {
    const data = {
      key: "portal--s1",
      title: "Portal",
      rarity: "epic",
      owned: "3",
      reserved: "1",
      max: "2",
      copies: "4",
      otherCopies: "5",
    }
    expect(cardFrom(data)).toEqual({ ...data, owned: 3, reserved: 1, max: 2, copies: 4, otherCopies: 5 })
  })

  it("falls back to empty words, the common tier and zeros", () => {
    expect(cardFrom({ owned: "many", max: "" })).toEqual({
      key: "",
      title: "",
      rarity: "common",
      owned: 0,
      reserved: 0,
      max: 0,
      copies: 0,
      otherCopies: 0,
    })
  })
})

describe("lineFrom", () => {
  it("reads a line's key and quantity, none as an empty key and zero", () => {
    expect(lineFrom({ key: "portal--s1", quantity: "2" })).toEqual({ key: "portal--s1", quantity: 2 })
    expect(lineFrom({})).toEqual({ key: "", quantity: 0 })
  })
})
