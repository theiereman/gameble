import { describe, expect, it } from "vitest"
import {
  chipsOn,
  countOf,
  countsByGroup,
  groupNames,
  priceGroup,
  reloadOnChange,
  reloadsSets,
  SET_OPTIONS_FRAME,
  submitToFrame,
  totalOf,
  type FrameSubmitter,
} from "./collection_filters"

function fakeSubmitter(): FrameSubmitter & { removed: boolean } {
  return {
    type: "button",
    dataset: {},
    removed: false,
    remove() {
      this.removed = true
    },
  }
}

describe("reloadOnChange", () => {
  it("reloads the grid for any chip, the set chips for the set kind, nothing for the text fields", () => {
    expect(reloadOnChange({ type: "checkbox", name: "rarity[]" })).toBe("grid")
    expect(reloadOnChange({ type: "checkbox", name: "sets[]" })).toBe("grid")
    expect(reloadOnChange({ type: "radio", name: "set_kind" })).toBe("sets")
    expect(reloadOnChange({ type: "radio", name: "sort" })).toBe("grid")
    expect(reloadOnChange({ type: "text", name: "min_price" })).toBe("grid")
    expect(reloadOnChange({ type: "text", name: "max_price" })).toBe("grid")
    expect(reloadOnChange({ type: "radio", name: "other" })).toBe("none")
    expect(reloadOnChange({ type: "search", name: "set_q" })).toBe("none")
    expect(reloadOnChange({ type: "search", name: "q" })).toBe("none")
  })
})

describe("reloadsSets", () => {
  it("tells the set chips' submitter from the grid's", () => {
    expect(reloadsSets({ dataset: { turboFrame: SET_OPTIONS_FRAME } })).toBe(true)
    expect(reloadsSets({ dataset: { turboFrame: "collection-results" } })).toBe(false)
    expect(reloadsSets({ dataset: {} })).toBe(false)
    expect(reloadsSets(null)).toBe(false)
    expect(reloadsSets(undefined)).toBe(false)
  })
})

describe("submitToFrame", () => {
  it("submits the form through a submitter aimed at the frame, then takes it away", () => {
    const submitter = fakeSubmitter()
    const appended: FrameSubmitter[] = []
    const submitted: { frame: string | undefined; type: string; removed: boolean }[] = []
    const form = {
      append: (node: typeof submitter) => appended.push(node),
      requestSubmit: (node: typeof submitter) =>
        submitted.push({ frame: node.dataset.turboFrame, type: node.type, removed: node.removed }),
    }

    submitToFrame(form, submitter, SET_OPTIONS_FRAME)

    expect(appended).toEqual([submitter])
    expect(submitted).toEqual([{ frame: SET_OPTIONS_FRAME, type: "submit", removed: false }])
    expect(submitter.removed).toBe(true)
  })

  it("takes the submitter away even when the submission throws", () => {
    const submitter = fakeSubmitter()
    const form = {
      append: () => {},
      requestSubmit: () => {
        throw new Error("not a submit button of this form")
      },
    }

    expect(() => submitToFrame(form, submitter, SET_OPTIONS_FRAME)).toThrow()
    expect(submitter.removed).toBe(true)
  })
})

describe("chipsOn", () => {
  it("counts the chips checked, the state's fallback alone counting none", () => {
    expect(chipsOn({ name: "rarity", checked: [] })).toBe(0)
    expect(chipsOn({ name: "rarity", checked: ["rare", "epic"] })).toBe(2)
    expect(chipsOn({ name: "state", checked: ["all"], fallback: "all" })).toBe(0)
    expect(chipsOn({ name: "state", checked: ["missing"], fallback: "all" })).toBe(1)
    expect(chipsOn({ name: "state", checked: ["owned", "missing"], fallback: "all" })).toBe(2)
  })
})

describe("countsByGroup", () => {
  const counts = countsByGroup([
    { name: "state", checked: ["missing"], fallback: "all" },
    { name: "goals", checked: [] },
    { name: "rarity", checked: ["rare"] },
    { name: "sets", checked: ["theme:horror", "theme:rpg"] },
    { name: "genre", checked: ["rpg"] },
  ])

  it("counts each group apart, and a pastille the groups it names", () => {
    expect(countOf(counts, ["rarity"])).toBe(1)
    expect(countOf(counts, ["state"])).toBe(1)
    expect(countOf(counts, ["goals"])).toBe(0)
    expect(countOf(counts, ["sets", "genre"])).toBe(3)
    expect(countOf(counts, ["absent"])).toBe(0)
  })

  it("sums every group for the whole form", () => {
    expect(totalOf(counts)).toBe(5)
    expect(totalOf(countsByGroup([]))).toBe(0)
  })
})

describe("groupNames", () => {
  it("reads the groups a pastille names, space separated", () => {
    expect(groupNames("sets genre")).toEqual(["sets", "genre"])
    expect(groupNames("rarity")).toEqual(["rarity"])
    expect(groupNames("")).toEqual([])
    expect(groupNames(undefined)).toEqual([])
  })
})

describe("priceGroup", () => {
  it("counts a chosen order and each filled bound, none when nothing is chosen", () => {
    expect(chipsOn(priceGroup("", "", ""))).toBe(0)
    expect(chipsOn(priceGroup("price_desc", "", ""))).toBe(1)
    expect(chipsOn(priceGroup("", "100", ""))).toBe(1)
    expect(chipsOn(priceGroup("price_asc", "100", "5000"))).toBe(3)
  })

  it("ignores a blank bound", () => {
    expect(chipsOn(priceGroup("", "  ", "5000"))).toBe(1)
  })

  it("adds to the total with the other groups", () => {
    const counts = countsByGroup([{ name: "rarity", checked: ["rare"] }, priceGroup("price_asc", "", "900")])

    expect(totalOf(counts)).toBe(3)
    expect(countOf(counts, ["price"])).toBe(2)
  })
})
