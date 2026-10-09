import { describe, expect, it } from "vitest"
import { TRAIL_KEY, TRAIL_SPAN, entryAfter, entryBefore, labelBefore, recordEntry, resetTrail, stepsBackTo, type TrailStorage } from "./history_trail"

function memory(): TrailStorage & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return {
    items,
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
  }
}

describe("history trail", () => {
  it("finds the nearest earlier entry showing a path", () => {
    const storage = memory()
    recordEntry(0, "/en", storage)
    recordEntry(1, "/en/library/tome/action-1", storage)
    recordEntry(2, "/en/cards/portal/seasons/1", storage)

    expect(stepsBackTo("/en/library/tome/action-1", 2, storage)).toBe(1)
    expect(stepsBackTo("/en", 2, storage)).toBe(2)
  })

  it("takes the nearest of several", () => {
    const storage = memory()
    for (const [index, path] of ["/grid", "/card", "/grid", "/other", "/card"].entries()) recordEntry(index, path, storage)

    expect(stepsBackTo("/grid", 4, storage)).toBe(2)
  })

  it("never answers the current entry or a later one", () => {
    const storage = memory()
    recordEntry(0, "/a", storage)
    recordEntry(1, "/grid", storage)
    recordEntry(2, "/grid", storage)

    expect(stepsBackTo("/grid", 1, storage)).toBeNull()
    expect(stepsBackTo("/b", 2, storage)).toBeNull()
  })

  it("a replaced entry overwrites its index", () => {
    const storage = memory()
    recordEntry(0, "/grid", storage)
    recordEntry(1, "/cards/a", storage)
    recordEntry(1, "/cards/b", storage)

    expect(stepsBackTo("/cards/a", 2, storage)).toBeNull()
    expect(stepsBackTo("/cards/b", 2, storage)).toBe(1)
  })

  it("keeps only entries near the current one", () => {
    const storage = memory()
    recordEntry(0, "/far", storage)
    recordEntry(TRAIL_SPAN + 1, "/here", storage)

    expect(Object.keys(JSON.parse(storage.items.get(TRAIL_KEY) ?? "{}"))).toEqual([String(TRAIL_SPAN + 1)])
  })

  it("starts afresh on a reset: entries of an earlier document are not trusted", () => {
    const storage = memory()
    recordEntry(0, "/en", storage)
    recordEntry(1, "/grid", storage)
    recordEntry(2, "/cards/a", storage)

    resetTrail(storage)
    recordEntry(0, "/en/hub", storage)
    recordEntry(1, "/cards/a", storage)

    expect(stepsBackTo("/grid", 2, storage)).toBeNull()
    expect(stepsBackTo("/en/hub", 1, storage)).toBe(1)
    expect(() => resetTrail(null)).not.toThrow()
  })

  it("names the page right after the current entry: the one the user came back from", () => {
    const storage = memory()
    recordEntry(0, "/en", storage)
    recordEntry(1, "/grid", storage)
    recordEntry(2, "/cards/a", storage)
    // ◀ ▶ replaced the detail's entry; then Back to the grid.
    recordEntry(2, "/cards/b", storage)
    recordEntry(1, "/grid", storage)

    expect(entryAfter(1, storage)).toBe("/cards/b")
    expect(entryAfter(0, storage)).toBe("/grid")
    expect(entryAfter(2, storage)).toBeNull()
    expect(entryAfter(1, null)).toBeNull()
    resetTrail(storage)
    expect(entryAfter(1, storage)).toBeNull()
  })

  it("is empty without storage, or with a broken or refusing one", () => {
    expect(stepsBackTo("/grid", 3, null)).toBeNull()
    recordEntry(0, "/grid", null)

    const broken = memory()
    broken.items.set(TRAIL_KEY, "{not json")
    expect(stepsBackTo("/grid", 3, broken)).toBeNull()
    recordEntry(0, "/grid", broken)
    expect(stepsBackTo("/grid", 1, broken)).toBe(1)

    const refusing: TrailStorage = {
      getItem: () => {
        throw new Error("denied")
      },
      setItem: () => {
        throw new Error("denied")
      },
    }
    expect(() => recordEntry(0, "/grid", refusing)).not.toThrow()
    expect(stepsBackTo("/grid", 1, refusing)).toBeNull()
  })

  it("names the screen right before the current entry, by the label it recorded", () => {
    const storage = memory()
    recordEntry(0, "/en", storage)
    recordEntry(1, "/en/library", storage, "Collection")
    recordEntry(2, "/en/cards/portal", storage, "Card")

    expect(labelBefore(2, storage)).toBe("Collection")
    expect(entryBefore(2, storage)).toBe("/en/library")
    expect(labelBefore(1, storage)).toBeNull()
    expect(entryBefore(1, storage)).toBe("/en")
  })

  it("keeps the label before a replaced entry: stepping through details names the screen they were opened from", () => {
    const storage = memory()
    recordEntry(0, "/en/library", storage, "Collection")
    recordEntry(1, "/en/cards/a", storage, "Card")
    recordEntry(1, "/en/cards/b", storage, "Card")

    expect(labelBefore(1, storage)).toBe("Collection")
    expect(stepsBackTo("/en/cards/b", 2, storage)).toBe(1)
  })

  it("names nothing before an entry it never recorded, after a reset, or with an empty label", () => {
    const storage = memory()
    recordEntry(3, "/en/cards/a", storage, "Card")
    expect(labelBefore(3, storage)).toBeNull()
    expect(entryBefore(3, storage)).toBeNull()
    expect(labelBefore(0, storage)).toBeNull()

    recordEntry(4, "/en/feed", storage, "")
    expect(labelBefore(5, storage)).toBeNull()

    recordEntry(5, "/en/friends", storage, "Friends")
    resetTrail(storage)
    expect(labelBefore(6, storage)).toBeNull()
  })

  it("names nothing without storage, with a refusing one, or from entries it cannot read", () => {
    expect(labelBefore(1, null)).toBeNull()
    expect(entryBefore(1, null)).toBeNull()

    const refusing: TrailStorage = {
      getItem: () => {
        throw new Error("denied")
      },
      setItem: () => {
        throw new Error("denied")
      },
    }
    expect(() => recordEntry(0, "/en/library", refusing, "Collection")).not.toThrow()
    expect(labelBefore(1, refusing)).toBeNull()

    const odd = memory()
    odd.items.set(TRAIL_KEY, JSON.stringify({ 0: "/en/library", 1: { pathname: "/en/feed", label: 7 } }))
    expect(labelBefore(1, odd)).toBeNull()
    expect(labelBefore(2, odd)).toBeNull()
    expect(stepsBackTo("/en/library", 2, odd)).toBeNull()
  })
})
