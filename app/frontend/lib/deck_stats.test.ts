import { describe, expect, it } from "vitest"
import { barsOf } from "./deck_stats"

describe("barsOf", () => {
  it("reads each stat as its percentile, marks the extremes and the trump, and skips what has no value", () => {
    const bars = barsOf({ popularity: 97, rating: 4, release: 80, discovery: null, circulation: 50 }, "rating")

    expect(bars).toEqual([
      { stat: "popularity", value: 97, tier: 9, trump: false },
      { stat: "rating", value: 4, tier: 0, trump: true },
      { stat: "release", value: 80, tier: 8, trump: false },
      { stat: "circulation", value: 50, tier: 5, trump: false },
    ])
  })
})
