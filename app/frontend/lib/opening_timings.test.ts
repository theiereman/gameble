import { describe, expect, it } from "vitest"
import { NO_MARKS, openingTimings } from "./opening_timings"

describe("openingTimings", () => {
  it("measures the blast and the first face from the touch, in whole milliseconds", () => {
    const timings = openingTimings({ touchedAt: 100.2, blastAt: 912.9 }, [2400.4, 1650.6, undefined], "phone")
    expect(timings).toEqual({ touch_to_blast: 813, touch_to_first_face: 1550, layout: "phone" })
  })

  it("leaves out a moment not reached yet", () => {
    expect(openingTimings({ touchedAt: 100, blastAt: null }, [undefined, undefined], "narrow")).toEqual({
      layout: "narrow",
    })
  })

  it("leaves out a moment marked before the touch, a face of the previous hand", () => {
    expect(openingTimings({ touchedAt: 500, blastAt: 900 }, [0], "wide")).toEqual({
      touch_to_blast: 400,
      layout: "wide",
    })
  })

  it("measures nothing without a touch, as for a hand restored from the page", () => {
    expect(openingTimings(NO_MARKS, [10, 20], "wide")).toEqual({})
  })
})
