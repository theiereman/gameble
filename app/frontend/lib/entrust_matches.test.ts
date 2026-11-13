import { describe, expect, it } from "vitest"
import { matchesOf } from "./entrust_matches"

const row = { ref: "portal:1", title: "Portal", rarity: "rare", season: 1, free: 2, owned: 3, value: 5000 }

describe("the matching editions the server answers", () => {
  it("reads each row as a copy", () => {
    expect(matchesOf([row])).toEqual([row])
    expect(matchesOf([])).toEqual([])
  })

  it("refuses an answer that is not a list of well-formed rows", () => {
    expect(matchesOf({ rows: [row] })).toBeNull()
    expect(matchesOf([{ ...row, rarity: "mythic" }])).toBeNull()
    expect(matchesOf([{ ...row, free: "2" }])).toBeNull()
    expect(matchesOf([row, null])).toBeNull()
  })
})
