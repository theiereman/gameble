import { describe, expect, it } from "vitest"
import { reloadOnChange, reloadsSets, SET_OPTIONS_FRAME, submitToFrame, type FrameSubmitter } from "./collection_filters"

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
