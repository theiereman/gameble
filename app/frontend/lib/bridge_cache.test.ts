import { describe, expect, it, vi } from "vitest"
import { forgetSnapshotsBeforeBridge, isBridgeAddress } from "./bridge_cache"

describe("isBridgeAddress", () => {
  it.each(["https://gameble.test/en", "https://gameble.test/fr/", "http://localhost:3000/en?x=1", "/fr"])("recognises %s", (href) => {
    expect(isBridgeAddress(href)).toBe(true)
  })

  it.each([
    "https://gameble.test/en/collection",
    "https://gameble.test/fr/boosters/new",
    "https://gameble.test/",
    "https://gameble.test/de",
    "https://gameble.test/english",
  ])("rejects %s", (href) => {
    expect(isBridgeAddress(href)).toBe(false)
  })
})

describe("forgetSnapshotsBeforeBridge", () => {
  it("empties the cache for a visit to the bridge", () => {
    const cache = { clear: vi.fn() }
    expect(forgetSnapshotsBeforeBridge("https://gameble.test/en", cache)).toBe(true)
    expect(cache.clear).toHaveBeenCalledOnce()
  })

  it("keeps the cache for any other screen", () => {
    const cache = { clear: vi.fn() }
    expect(forgetSnapshotsBeforeBridge("https://gameble.test/en/collection", cache)).toBe(false)
    expect(cache.clear).not.toHaveBeenCalled()
  })
})
