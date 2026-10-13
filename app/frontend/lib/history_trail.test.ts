import { describe, expect, it } from "vitest"
import { TRAIL_KEY, TRAIL_SPAN, entryAfter, previousScreen, readTrail, recordEntry, resetTrail, stepsBackTo, type TrailStorage } from "./history_trail"

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

  describe("the previous screen", () => {
    function trailOf(...entries: Array<[string, string?]>): ReturnType<typeof readTrail> {
      const storage = memory()
      entries.forEach(([pathname, label], index) => recordEntry(index, pathname, storage, label))
      return readTrail(storage)
    }

    it("is the entry right before, one step back, when it shows another screen", () => {
      const trail = trailOf(["/en"], ["/en/library", "Collection"], ["/en/cards/portal", "Card"])

      expect(previousScreen(trail, 2, "Card")).toEqual({ label: "Collection", pathname: "/en/library", steps: 1 })
    })

    it("is hidden on a later page of a screen reached from the hub", () => {
      const trail = trailOf(["/en"], ["/en/library", "Collection"], ["/en/library", "Collection"], ["/en/library", "Collection"])

      expect(previousScreen(trail, 3, "Collection")).toBeNull()
    })

    it("names the grid page a card detail was opened from, one step back", () => {
      const trail = trailOf(["/en"], ["/en/library", "Collection"], ["/en/library", "Collection"], ["/en/cards/portal", "Card"])

      expect(previousScreen(trail, 3, "Card")).toEqual({ label: "Collection", pathname: "/en/library", steps: 1 })
    })

    it("goes back past the pages of the current screen to the screen before them", () => {
      const trail = trailOf(["/en"], ["/en/cards/portal", "Card"], ["/en/library", "Collection"], ["/en/library", "Collection"])

      expect(previousScreen(trail, 3, "Collection")).toEqual({ label: "Card", pathname: "/en/cards/portal", steps: 2 })
    })

    it("stops at the hub, even with a labelled screen before it", () => {
      const trail = trailOf(["/en/friends", "Friends"], ["/en"], ["/en/library", "Collection"])

      expect(previousScreen(trail, 2, "Collection")).toBeNull()
    })

    it("is hidden when the entry it reaches was never recorded", () => {
      const storage = memory()
      recordEntry(3, "/en/library", storage, "Collection")
      recordEntry(4, "/en/library", storage, "Collection")

      expect(previousScreen(readTrail(storage), 4, "Collection")).toBeNull()
      expect(previousScreen(readTrail(storage), 0, "Collection")).toBeNull()
      expect(previousScreen({}, 2, "Card")).toBeNull()
    })

    it("keeps the screen a detail was opened from while ◀ ▶ replace its entry", () => {
      const storage = memory()
      recordEntry(0, "/en/library", storage, "Collection")
      recordEntry(1, "/en/cards/a", storage, "Card")
      recordEntry(1, "/en/cards/b", storage, "Card")

      expect(previousScreen(readTrail(storage), 1, "Card")).toEqual({ label: "Collection", pathname: "/en/library", steps: 1 })
    })

    it("treats an empty label as none, and skips nothing on an unnamed screen", () => {
      expect(previousScreen(trailOf(["/en/library", "Collection"], ["/en/feed", ""]), 2, "Card")).toBeNull()
      expect(previousScreen(trailOf(["/en"], ["/en/library", "Collection"]), 2, null)).toEqual({ label: "Collection", pathname: "/en/library", steps: 1 })
    })

    it("finds nothing after a reset, without storage, or from entries it cannot read", () => {
      const storage = memory()
      recordEntry(0, "/en/friends", storage, "Friends")
      resetTrail(storage)
      expect(previousScreen(readTrail(storage), 1, "Card")).toBeNull()
      expect(previousScreen(readTrail(null), 1, "Card")).toBeNull()

      const refusing: TrailStorage = {
        getItem: () => {
          throw new Error("denied")
        },
        setItem: () => {
          throw new Error("denied")
        },
      }
      expect(() => recordEntry(0, "/en/library", refusing, "Collection")).not.toThrow()
      expect(previousScreen(readTrail(refusing), 1, "Card")).toBeNull()

      const odd = memory()
      odd.items.set(TRAIL_KEY, JSON.stringify({ 0: "/en/library", 1: { pathname: "/en/feed", label: 7 } }))
      expect(previousScreen(readTrail(odd), 2, "Card")).toBeNull()
      expect(stepsBackTo("/en/library", 2, odd)).toBeNull()
    })
  })
})
