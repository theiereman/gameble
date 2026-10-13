import { describe, expect, it } from "vitest"
import { submitOnce, type SubmittableForm } from "./auto_submit"

function fakeForm(dataset: Record<string, string> = {}): SubmittableForm & { submits: number } {
  return {
    dataset,
    submits: 0,
    requestSubmit() {
      this.submits += 1
    },
  }
}

describe("submitOnce", () => {
  it("submits the form, replacing the page in history", () => {
    const form = fakeForm()

    expect(submitOnce(form, { preview: false })).toBe(true)

    expect(form.submits).toBe(1)
    expect(form.dataset.turboAction).toBe("replace")
  })

  it("submits a form only once", () => {
    const form = fakeForm()

    submitOnce(form, { preview: false })
    expect(submitOnce(form, { preview: false })).toBe(false)

    expect(form.submits).toBe(1)
  })

  it("skips a form already marked submitted, as in a restored snapshot", () => {
    const form = fakeForm({ autoSubmitted: "" })

    expect(submitOnce(form, { preview: false })).toBe(false)

    expect(form.submits).toBe(0)
  })

  it("never submits from a preview, and leaves the form untouched", () => {
    const form = fakeForm()

    expect(submitOnce(form, { preview: true })).toBe(false)

    expect(form.submits).toBe(0)
    expect(form.dataset).toEqual({})
  })
})
