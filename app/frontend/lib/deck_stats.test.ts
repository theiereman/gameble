import { describe, expect, it } from "vitest"
import { barsOf } from "./deck_stats"

describe("barsOf", () => {
  it("reads each stat as its percentile, marks the extremes and the trump, and skips what has no value", () => {
    const bars = barsOf({ popularity: 97, rating: 4, release: 80, discovery: null, circulation: 50 }, "rating")

    expect(bars).toEqual([
      { stat: "popularity", value: 97, tier: "highest", trump: false },
      { stat: "rating", value: 4, tier: "lowest", trump: true },
      { stat: "release", value: 80, tier: "high", trump: false },
      { stat: "circulation", value: 50, tier: "mid", trump: false },
    ])
  })
})
