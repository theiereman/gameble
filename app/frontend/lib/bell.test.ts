import { describe, expect, it } from "vitest"
import {
  BELL_SEEN_CAP,
  dismissibleKeys,
  hiddenLines,
  linesSeenHere,
  markSeen,
  opensTarget,
  readSeen,
  seenStorageKey,
  type BellLine,
  type BellStorage,
} from "./bell"

const OWNER = "hugo-token"

function memory(): BellStorage & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return {
    items,
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
  }
}

const refusing: BellStorage = {
  getItem: () => {
    throw new Error("denied")
  },
  setItem: () => {
    throw new Error("denied")
  },
}

const trade: BellLine = { key: "trade:abc:1", path: "/en/trades/abc", lasting: false }
const invitation: BellLine = { key: "invitation:def", path: "/en/friends", lasting: false }
const daily: BellLine = { key: "daily:2026-10-07", path: "/en/booster", lasting: true }

describe("bell seen set", () => {
  it("remembers the lines seen, once each, newest last", () => {
    const storage = memory()
    markSeen(["trade:abc:1"], storage, OWNER)
    markSeen(["mission:2026-10-05", "trade:abc:1"], storage, OWNER)

    expect(JSON.parse(storage.items.get(seenStorageKey(OWNER)) ?? "")).toEqual(["mission:2026-10-05", "trade:abc:1"])
    expect(readSeen(storage, OWNER)).toEqual(new Set(["mission:2026-10-05", "trade:abc:1"]))
  })

  it("keeps each player's seen lines apart on a shared browser", () => {
    const storage = memory()
    markSeen(["mission:2026-10-05"], storage, OWNER)

    expect(readSeen(storage, "lea-token")).toEqual(new Set())
    expect(readSeen(storage, OWNER)).toEqual(new Set(["mission:2026-10-05"]))
  })

  it("keeps only the newest keys past the cap", () => {
    const storage = memory()
    for (let week = 0; week < BELL_SEEN_CAP + 5; week++) markSeen([`mission:${week}`], storage, OWNER)

    const seen = readSeen(storage, OWNER)
    expect(seen.size).toBe(BELL_SEEN_CAP)
    expect(seen.has("mission:0")).toBe(false)
    expect(seen.has(`mission:${BELL_SEEN_CAP + 4}`)).toBe(true)
  })

  it("sees nothing without storage, with refusing storage, or with a damaged entry", () => {
    expect(readSeen(null, OWNER)).toEqual(new Set())
    expect(() => markSeen(["trade:abc:1"], refusing, OWNER)).not.toThrow()
    expect(readSeen(refusing, OWNER)).toEqual(new Set())

    const damaged = memory()
    damaged.items.set(seenStorageKey(OWNER), "{not json")
    expect(readSeen(damaged, OWNER)).toEqual(new Set())
    damaged.items.set(seenStorageKey(OWNER), JSON.stringify({ trade: 1 }))
    expect(readSeen(damaged, OWNER)).toEqual(new Set())
    damaged.items.set(seenStorageKey(OWNER), JSON.stringify(["mission:1", 7]))
    expect(readSeen(damaged, OWNER)).toEqual(new Set(["mission:1"]))
  })

  it("writes nothing for no key", () => {
    const storage = memory()
    markSeen(["", ""], storage, OWNER)

    expect(storage.items.has(seenStorageKey(OWNER))).toBe(false)
  })
})

describe("bell lines", () => {
  it("a line's target is opened only on its exact pathname", () => {
    expect(opensTarget("/en/trades/abc", "/en/trades/abc")).toBe(true)
    expect(opensTarget("/en/trades/abc", "/en/trades/abcd")).toBe(false)
    expect(opensTarget("/en/friends", "/fr/friends")).toBe(false)
    expect(opensTarget(undefined, "/en/friends")).toBe(false)
    expect(opensTarget("", "")).toBe(false)
  })

  it("the page opened sees the lines leading to it, never a lasting one", () => {
    expect(linesSeenHere([trade, invitation, daily], "/en/friends")).toEqual(["invitation:def"])
    expect(linesSeenHere([trade, invitation, daily], "/en/booster")).toEqual([])
  })

  it("hides the seen lines; a lasting line stays until its state ends", () => {
    const seen = new Set(["trade:abc:1", "daily:2026-10-07"])

    expect(hiddenLines([trade, invitation, daily], seen)).toEqual(new Set(["trade:abc:1"]))
    expect(hiddenLines([trade, invitation], new Set(["trade:abc:1", "invitation:def"])).size).toBe(2)
    expect(hiddenLines([], seen).size).toBe(0)
  })
})

describe("dismissibleKeys", () => {
  it("lists the lines that can be seen away, not the lasting ones", () => {
    const lines: BellLine[] = [
      { key: "trade:abc:1", path: "/en/trades/abc", lasting: false },
      { key: "daily:2026-11-04", path: "/en/booster", lasting: true },
    ]

    expect(dismissibleKeys(lines)).toEqual(["trade:abc:1"])
    expect(dismissibleKeys([])).toEqual([])
  })
})
