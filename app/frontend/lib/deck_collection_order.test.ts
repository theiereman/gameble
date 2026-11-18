import { describe, expect, it } from "vitest"
import { callValue, sortRefs, visibleRefs, type Ranked } from "./deck_collection_order"

const ranked = (release: number | null, trump = "release"): Ranked => ({
  percentiles: { popularity: 50, rating: 50, release, discovery: 50, circulation: 50 },
  trump,
  title: "Some Game",
})

const entries: Record<string, Ranked> = {
  "a:1": ranked(80),
  "b:1": ranked(10),
  "c:1": ranked(null, ""),
  "d:1": ranked(10, "popularity"),
  "e:1": ranked(45),
}
const order = ["a:1", "b:1", "c:1", "d:1", "e:1"]

describe("callValue", () => {
  it("reads a high call as the percentile and a low one as its complement, and nothing without a percentile", () => {
    expect(callValue({ release: 80 }, "release-high")).toBe(80)
    expect(callValue({ release: 80 }, "release-low")).toBe(20)
    expect(callValue({ release: null }, "release-low")).toBeNull()
    expect(callValue({}, "rating-high")).toBeNull()
  })
})

describe("sortRefs", () => {
  it("keeps the server's title order by title", () => {
    expect(sortRefs(entries, order, "title")).toEqual(order)
  })

  it("orders by a call, the best first, cards with no value in it last, ties in the server's order", () => {
    expect(sortRefs(entries, order, "release-low")).toEqual(["b:1", "d:1", "e:1", "a:1", "c:1"])
    expect(sortRefs(entries, order, "release-high")).toEqual(["a:1", "e:1", "b:1", "d:1", "c:1"])
  })
})

describe("visibleRefs", () => {
  it("keeps the cards whose title holds every typed word, ignoring case and accents", () => {
    const named = { "x:1": { ...ranked(50), title: "Pokémon Red Edition" }, "y:1": { ...ranked(50), title: "Portal" } }
    expect(visibleRefs(named, ["x:1", "y:1"], "all", "pokemon edit")).toEqual(["x:1"])
    expect(visibleRefs(named, ["x:1", "y:1"], "all", "  ")).toEqual(["x:1", "y:1"])
    expect(visibleRefs(named, ["x:1", "y:1"], "all", "zzz")).toEqual([])
  })

  it("keeps every card for all trumps, else only the cards whose trump is that stat, in the order given", () => {
    expect(visibleRefs(entries, order, "all")).toEqual(order)
    expect(visibleRefs(entries, ["e:1", "a:1", "b:1", "d:1"], "release")).toEqual(["e:1", "a:1", "b:1"])
    expect(visibleRefs(entries, order, "circulation")).toEqual([])
  })
})
