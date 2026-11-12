import { describe, expect, it } from "vitest"
import { choose, setStart, start, validate, type Edition, type ListingState } from "./listing_form"
import {
  fieldsViewOf,
  gridViewOf,
  refusalText,
  statusOf,
  stepText,
  summaryViewOf,
  type Forms,
  type ListingStrings,
} from "./listing_form_view"

const strings: ListingStrings = {
  amount: "%{amount} PiCoins",
  invalidPrice: "Enter a whole number of PiCoins, above zero.",
  minimumHint: "At least %{amount} for a %{rarity}",
  minimumRefusal: "At least %{amount} for a %{rarity}.",
  status: "You receive %{amount} PiCoins",
  step: "Step %{step} of 2",
}
const forms: Forms = { locale: "en", strings }

const rare: Edition = {
  ref: "alpha:1",
  title: "Alpha",
  rarity: "rare",
  rarityName: "rare",
  season: 1,
  free: 1,
  minimum: 1_000,
  stamp: 500,
}
const common: Edition = { ...rare, ref: "beta:1", rarity: "common", rarityName: "common", minimum: 100, stamp: 50 }

function stateWith(values: { start?: string }, chosen: string | null = "alpha:1"): ListingState {
  return start([rare, common], 1_000, { start: "", duration: "24", ...values }, chosen, "wide")
}

describe("grid view", () => {
  it("marks the chosen edition and makes it the one tab stop", () => {
    const view = gridViewOf(stateWith({}, "beta:1"))

    expect(view.cells).toEqual([
      { ref: "alpha:1", chosen: false, tabbable: false },
      { ref: "beta:1", chosen: true, tabbable: true },
    ])
    expect(view.chosen).toBe("beta:1")
  })

  it("makes the first edition the tab stop while none is chosen", () => {
    const view = gridViewOf(stateWith({}, null))

    expect(view.cells.map((cell) => cell.tabbable)).toEqual([true, false])
    expect(view.chosen).toBe("")
  })

  it("changes the chosen edition only when one is chosen", () => {
    expect(gridViewOf(choose(stateWith({}, null), "alpha:1")).chosen).toBe("alpha:1")
  })
})

describe("fields view", () => {
  it("locks the fields and writes no hint before an edition is chosen", () => {
    expect(fieldsViewOf(stateWith({}, null), forms)).toMatchObject({ chosen: "", hint: "", locked: true })
  })

  it("writes the minimum of the chosen edition", () => {
    expect(fieldsViewOf(stateWith({}), forms)).toMatchObject({
      chosen: "alpha:1",
      hint: "At least 1,000 for a rare",
      locked: false,
      duration: "24",
    })
  })

  it("shows a refusal under its field once validated, and none before", () => {
    const state = stateWith({ start: "abc" })

    expect(fieldsViewOf(state, forms).start.error).toBeNull()
    expect(fieldsViewOf(validate(state), forms).start.error).toBe(strings.invalidPrice)
  })

  it("names the minimum and the rarity in the refusal of a low start", () => {
    const state = validate(stateWith({ start: "10" }))

    expect(state.shown && refusalText(state.shown, state, forms)).toBe("At least 1,000 for a rare.")
  })

  it("asks for a whole number when the start is not a price", () => {
    expect(fieldsViewOf(validate(stateWith({ start: "x" })), forms).start.error).toBe(strings.invalidPrice)
  })

  it("clears the refusal on the next edit", () => {
    const shown = validate(stateWith({ start: "10" }))

    expect(fieldsViewOf(setStart(shown, "1000"), forms).start.error).toBeNull()
  })
})

describe("summary view", () => {
  it("shows the stamp and no other figure while the start is empty", () => {
    expect(summaryViewOf(stateWith({}), forms, true)).toEqual({
      stamp: 500,
      commission: null,
      received: null,
      disabled: false,
      status: "",
    })
  })

  it("shows the lines and the status sentence for a start", () => {
    expect(summaryViewOf(stateWith({ start: "1300" }), forms, true)).toEqual({
      stamp: 500,
      commission: 130,
      received: 1_170,
      disabled: false,
      status: "You receive 1,170 PiCoins",
    })
  })

  it("shows no figure and no status for an amount beyond the safe integers", () => {
    const view = summaryViewOf(stateWith({ start: "9007199254740993" }), forms, true)

    expect(view).toMatchObject({ stamp: 500, commission: null, received: null, status: "" })
  })

  it("disables the button before an edition is chosen and while the market is closed", () => {
    expect(summaryViewOf(stateWith({}, null), forms, true)).toMatchObject({ stamp: null, disabled: true })
    expect(summaryViewOf(stateWith({}), forms, false).disabled).toBe(true)
  })

  it("writes the status in the player's locale", () => {
    expect(statusOf(1_170, { locale: "fr", strings })).toBe("You receive 1\u00A0170 PiCoins")
    expect(statusOf(null, forms)).toBe("")
  })
})

describe("step text", () => {
  it("names the step", () => {
    expect(stepText(stateWith({}, null), forms)).toBe("Step 1 of 2")
    expect(stepText(stateWith({}), forms)).toBe("Step 2 of 2")
  })
})
