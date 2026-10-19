import { describe, expect, it } from "vitest"
import { PICKER_PAGE, batches, facesFrom, facesUrl, missingFaces, nextPage, shownFor, withFaces } from "./trade_faces"

describe("shownFor", () => {
  it("holds whole pages up to and including the index", () => {
    expect(shownFor(0)).toBe(PICKER_PAGE)
    expect(shownFor(PICKER_PAGE - 1)).toBe(PICKER_PAGE)
    expect(shownFor(PICKER_PAGE)).toBe(2 * PICKER_PAGE)
    expect(shownFor(2999)).toBe(Math.ceil(3000 / PICKER_PAGE) * PICKER_PAGE)
  })

  it("is one page for an index before the list", () => {
    expect(shownFor(-1)).toBe(PICKER_PAGE)
  })
})

describe("nextPage", () => {
  it("adds one page", () => {
    expect(nextPage(PICKER_PAGE)).toBe(2 * PICKER_PAGE)
  })
})

describe("missingFaces", () => {
  it("keeps the keys neither known nor asked for, once each, in order", () => {
    const known = new Map([["a--s1", "<span></span>"]])
    expect(missingFaces(["a--s1", "b--s1", "c--s1", "b--s1", "d--s1"], known, new Set(["c--s1"]))).toEqual(["b--s1", "d--s1"])
  })

  it("is empty when every face is known or pending", () => {
    expect(missingFaces(["a--s1"], new Map([["a--s1", ""]]), new Set())).toEqual([])
    expect(missingFaces([], new Map(), new Set())).toEqual([])
  })
})

describe("batches", () => {
  it("cuts the keys in runs of at most the size", () => {
    expect(batches(["a", "b", "c", "d", "e"], 2)).toEqual([["a", "b"], ["c", "d"], ["e"]])
    expect(batches(["a", "b"], 60)).toEqual([["a", "b"]])
  })

  it("is empty for no keys, and takes one at a time for a size under one", () => {
    expect(batches([], 60)).toEqual([])
    expect(batches(["a", "b"], 0)).toEqual([["a"], ["b"]])
  })
})

describe("facesUrl", () => {
  it("asks for each key as keys[], encoded", () => {
    expect(facesUrl("/fr/trades/faces", ["portal--s1", "a&b c--s2"])).toBe(
      "/fr/trades/faces?keys%5B%5D=portal--s1&keys%5B%5D=a%26b+c--s2",
    )
  })

  it("adds to a query the base already has", () => {
    expect(facesUrl("/fr/trades/faces?v=1", ["x--s1"])).toBe("/fr/trades/faces?v=1&keys%5B%5D=x--s1")
  })
})

describe("facesFrom", () => {
  it("reads the faces by key, keeping only text", () => {
    expect(facesFrom({ faces: { "a--s1": "<span>A</span>", "b--s1": 3 } })).toEqual({ "a--s1": "<span>A</span>" })
  })

  it("is empty for an answer of another shape", () => {
    expect(facesFrom(null)).toEqual({})
    expect(facesFrom({ error: { code: "forbidden" } })).toEqual({})
    expect(facesFrom({ faces: ["a"] })).toEqual({})
    expect(facesFrom("faces")).toEqual({})
  })
})

describe("withFaces", () => {
  it("adds the arrived faces to the known ones, leaving the known map untouched", () => {
    const known = new Map([["a--s1", "A"]])
    const next = withFaces(known, { "b--s1": "B" })
    expect([...next]).toEqual([
      ["a--s1", "A"],
      ["b--s1", "B"],
    ])
    expect(known.size).toBe(1)
  })

  it("keeps the same map when nothing arrived", () => {
    const known = new Map([["a--s1", "A"]])
    expect(withFaces(known, {})).toBe(known)
  })
})
