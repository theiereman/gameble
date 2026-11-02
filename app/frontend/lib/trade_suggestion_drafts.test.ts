import { describe, expect, it } from "vitest"
import { saveDraft } from "./trade_board_draft"
import { draftedKeys, successorOf } from "./trade_suggestion_drafts"

function memory(): Pick<Storage, "getItem" | "setItem" | "removeItem"> {
  const items = new Map<string, string>()
  return {
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
    removeItem: (key) => void items.delete(key),
  }
}

describe("draftedKeys", () => {
  it("keeps the keys of the friends with a stored draft only", () => {
    const storage = memory()
    saveDraft("hugo:lea", { take: [{ key: "hades--s1", quantity: 1 }] }, storage)

    expect(draftedKeys(["hugo:lea", "hugo:max"], storage)).toEqual(new Set(["hugo:lea"]))
  })

  it("keeps none without storage", () => {
    expect(draftedKeys(["hugo:lea"], null)).toEqual(new Set())
  })

  it("ignores an empty key", () => {
    expect(draftedKeys([""], memory())).toEqual(new Set())
  })
})

describe("successorOf", () => {
  it("is the next visible suggestion, else the previous one, else none", () => {
    expect(successorOf([false, true, false], 1)).toBe(2)
    expect(successorOf([false, false, true], 2)).toBe(1)
    expect(successorOf([true, true, true], 1)).toBeNull()
  })
})
