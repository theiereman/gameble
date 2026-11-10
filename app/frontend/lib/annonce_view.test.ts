import { describe, expect, it } from "vitest"
import { edit, start, type Terms } from "./annonce"
import { footViewOf, type Forms } from "./annonce_view"

const forms: Forms = {
  locale: "en",
  strings: {
    buttonBid: "BID · %{amount}",
    buttonBuy: "BUY · %{amount}",
    buttonIdle: "BID",
    buttonName: "Bid, maximum %{amount} PiCoins",
    buttonRaise: "RAISE · %{amount}",
    liveBuyNow: "Buys at once for %{amount}.",
    liveHold: "%{amount} held.",
    liveRaise: "%{amount} more held.",
  },
}

const terms = (overrides: Partial<Terms> = {}): Terms => ({
  minimum: 20_000,
  available: 100_000,
  buyNow: null,
  ownMaximum: null,
  price: 20_000,
  unusualMultiple: 3,
  ...overrides,
})

const typed = (text: string, overrides: Partial<Terms> = {}) => footViewOf(edit(start(terms(overrides)), text), forms)

describe("the foot", () => {
  it("is idle and silent before a valid amount", () => {
    expect(typed("")).toMatchObject({ button: "BID", name: null, live: "" })
    expect(typed("3x0")).toMatchObject({ button: "BID", name: null, live: "" })
  })

  it("names the typed maximum on the button and holds it in the live sentence", () => {
    expect(typed("30000")).toMatchObject({
      button: "BID · 30,000",
      name: "Bid, maximum 30,000 PiCoins",
      live: "30,000 held.",
    })
  })

  it("raises for a leader and holds only the difference", () => {
    expect(typed("35000", { ownMaximum: 30_000 })).toMatchObject({ button: "RAISE · 35,000", live: "5,000 more held." })
  })

  it("buys at the buy-now price when the maximum reaches it", () => {
    expect(typed("90000", { buyNow: 60_000 })).toMatchObject({
      button: "BUY · 60,000",
      live: "Buys at once for 60,000.",
    })
  })

  it("never shows a negative figure for a raise under the current maximum", () => {
    expect(typed("25000", { ownMaximum: 30_000 }).live).toBe("0 more held.")
  })

  it("hides the sentences and shows the panel after an answer, until the next keystroke", () => {
    const answered = footViewOf(start(terms(), true), forms)
    expect(answered).toMatchObject({ sentencesHidden: true, panelHidden: false })
    expect(typed("1")).toMatchObject({ sentencesHidden: false, panelHidden: true })
  })

  it("formats amounts for the locale", () => {
    const view = footViewOf(edit(start(terms()), "30000"), { ...forms, locale: "fr" })
    expect(view.button).toBe("BID · 30\u00a0000")
  })
})
