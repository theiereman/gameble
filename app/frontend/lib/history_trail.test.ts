import { describe, expect, it } from "vitest"
import { TRAIL_KEY, TRAIL_SPAN, recordEntry, resetTrail, stepsBackTo, type TrailStorage } from "./history_trail"

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
})
