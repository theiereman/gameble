import { describe, expect, it } from "vitest"
import { DRAFT_PREFIX, forgetDraft, parseDraft, readDraft, sameLines, saveDraft } from "./trade_board_draft"
import type { Line } from "./trade_board"

const lines = (...pairs: [string, number][]): Line[] => pairs.map(([key, quantity]) => ({ key, quantity }))

function memory(): Pick<Storage, "getItem" | "setItem" | "removeItem"> & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return {
    items,
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
    removeItem: (key) => void items.delete(key),
  }
}

describe("saveDraft, readDraft and forgetDraft", () => {
  it("keeps the sides under the prefixed key, reads them back and forgets them", () => {
    const storage = memory()
    saveDraft("hugo:lea", { give: lines(["portal--s1", 2]), take: lines(["hades--s1", 1]) }, storage)

    expect([...storage.items.keys()]).toEqual([`${DRAFT_PREFIX}hugo:lea`])
    expect(readDraft("hugo:lea", storage)).toEqual({ give: lines(["portal--s1", 2]), take: lines(["hades--s1", 1]) })
    expect(readDraft("hugo:max", storage)).toBeNull()

    forgetDraft("hugo:lea", storage)
    expect(readDraft("hugo:lea", storage)).toBeNull()
  })

  it("does nothing without storage or key, and survives a storage that throws", () => {
    expect(readDraft("hugo:lea", null)).toBeNull()
    expect(() => saveDraft("hugo:lea", {}, null)).not.toThrow()
    const storage = memory()
    saveDraft("", { give: lines(["a", 1]) }, storage)
    expect(storage.items.size).toBe(0)

    const refusing = {
      getItem: () => {
        throw new Error("denied")
      },
      setItem: () => {
        throw new Error("denied")
      },
      removeItem: () => {
        throw new Error("denied")
      },
    }
    expect(readDraft("hugo:lea", refusing)).toBeNull()
    expect(() => saveDraft("hugo:lea", { give: [] }, refusing)).not.toThrow()
    expect(() => forgetDraft("hugo:lea", refusing)).not.toThrow()
  })
})

describe("parseDraft", () => {
  it("keeps only well-formed lines of the two fields", () => {
    const raw = JSON.stringify({
      give: [
        { key: "portal--s1", quantity: 2 },
        { key: "", quantity: 1 },
        { key: "x", quantity: 0 },
        { key: "y", quantity: 1.5 },
        "z",
      ],
      take: "nothing",
      other: [{ key: "a", quantity: 1 }],
    })
    expect(parseDraft(raw)).toEqual({ give: lines(["portal--s1", 2]) })
  })

  it("answers null for what is not an object", () => {
    expect(parseDraft("not json")).toBeNull()
    expect(parseDraft("[]")).toBeNull()
    expect(parseDraft("null")).toBeNull()
  })
})

describe("sameLines", () => {
  it("compares cards and quantities in any order", () => {
    expect(sameLines(lines(["a", 1], ["b", 2]), lines(["b", 2], ["a", 1]))).toBe(true)
    expect(sameLines(lines(["a", 1]), lines(["a", 2]))).toBe(false)
    expect(sameLines(lines(["a", 1]), lines(["a", 1], ["b", 1]))).toBe(false)
    expect(sameLines([], [])).toBe(true)
  })
})
