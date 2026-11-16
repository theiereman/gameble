import { describe, expect, it, vi } from "vitest"
import {
  dismissibleKeys,
  hiddenLines,
  keysToSend,
  legacyStorageKey,
  linesSeenHere,
  opensTarget,
  READ_KEYS_PER_POST,
  sendRead,
  takeLegacySeen,
  type BellLine,
  type BellStorage,
} from "./bell"

const OWNER = "hugo-token"

function memory(): BellStorage & { items: Map<string, string> } {
  const items = new Map<string, string>()
  return {
    items,
    getItem: (key) => items.get(key) ?? null,
    removeItem: (key) => void items.delete(key),
  }
}

const refusing: BellStorage = {
  getItem: () => {
    throw new Error("denied")
  },
  removeItem: () => {
    throw new Error("denied")
  },
}

const trade: BellLine = { key: "trade:abc:1", path: "/en/trades/abc", lasting: false, read: false }
const invitation: BellLine = { key: "invitation:def", path: "/en/friends", lasting: false, read: false }
const daily: BellLine = { key: "daily:2026-10-07", path: "/en/booster", lasting: true, read: false }

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

  it("hides the lines read on any device or just now here; a lasting line stays until its state ends", () => {
    const readElsewhere = { ...invitation, read: true }

    expect(hiddenLines([trade, readElsewhere, daily], new Set())).toEqual(new Set(["invitation:def"]))
    expect(hiddenLines([trade, invitation, daily], new Set(["trade:abc:1", "daily:2026-10-07"]))).toEqual(
      new Set(["trade:abc:1"]),
    )
    expect(hiddenLines([{ ...daily, read: true }], new Set()).size).toBe(0)
    expect(hiddenLines([], new Set(["trade:abc:1"])).size).toBe(0)
  })
})

describe("dismissibleKeys", () => {
  it("lists the lines that can be read away, not the lasting ones", () => {
    expect(dismissibleKeys([trade, daily])).toEqual(["trade:abc:1"])
    expect(dismissibleKeys([])).toEqual([])
  })
})

describe("keysToSend", () => {
  it("sends each key once, never one the server or this page already holds", () => {
    const readElsewhere = { ...invitation, read: true }

    expect(keysToSend(["trade:abc:1", "trade:abc:1", "invitation:def", ""], [trade, readElsewhere], new Set())).toEqual(
      ["trade:abc:1"],
    )
    expect(keysToSend(["trade:abc:1"], [trade], new Set(["trade:abc:1"]))).toEqual([])
    expect(keysToSend(["mission:2026-10-05"], [], new Set())).toEqual(["mission:2026-10-05"])
  })
})

describe("takeLegacySeen", () => {
  it("hands over this browser's old seen lines once, then forgets them", () => {
    const storage = memory()
    storage.items.set(legacyStorageKey(OWNER), JSON.stringify(["trade:abc:1", 7, "", "mission:1"]))
    storage.items.set(legacyStorageKey("lea-token"), JSON.stringify(["invitation:def"]))

    expect(takeLegacySeen(storage, OWNER)).toEqual(["trade:abc:1", "mission:1"])
    expect(takeLegacySeen(storage, OWNER)).toEqual([])
    expect(storage.items.has(legacyStorageKey("lea-token"))).toBe(true)
  })

  it("finds nothing without storage, with refusing storage, or with a damaged entry", () => {
    expect(takeLegacySeen(null, OWNER)).toEqual([])
    expect(takeLegacySeen(refusing, OWNER)).toEqual([])

    const damaged = memory()
    damaged.items.set(legacyStorageKey(OWNER), "{not json")
    expect(takeLegacySeen(damaged, OWNER)).toEqual([])
    expect(damaged.items.has(legacyStorageKey(OWNER))).toBe(false)
  })

  it("keeps only the newest keys past one post", () => {
    const storage = memory()
    const keys = Array.from({ length: READ_KEYS_PER_POST + 5 }, (_, week) => `mission:${week}`)
    storage.items.set(legacyStorageKey(OWNER), JSON.stringify(keys))

    const taken = takeLegacySeen(storage, OWNER)
    expect(taken).toHaveLength(READ_KEYS_PER_POST)
    expect(taken[0]).toBe("mission:5")
  })
})

describe("sendRead", () => {
  it("posts the keys as JSON with the CSRF token", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))

    expect(await sendRead({ url: "/en/bell/read", keys: ["trade:abc:1"], csrfToken: "tok", fetch })).toBe(true)

    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe("/en/bell/read")
    expect(init.method).toBe("POST")
    expect(init.headers["X-CSRF-Token"]).toBe("tok")
    expect(JSON.parse(init.body)).toEqual({ keys: ["trade:abc:1"] })
  })

  it("posts nothing for no key and reports a refused or failed post", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(null, { status: 422 }))
    expect(await sendRead({ url: "/en/bell/read", keys: [], csrfToken: null, fetch })).toBe(true)
    expect(fetch).not.toHaveBeenCalled()

    expect(await sendRead({ url: "/en/bell/read", keys: ["trade:abc:1"], csrfToken: null, fetch })).toBe(false)
    const failing = vi.fn().mockRejectedValue(new Error("offline"))
    expect(await sendRead({ url: "/en/bell/read", keys: ["trade:abc:1"], csrfToken: null, fetch: failing })).toBe(false)
  })
})
