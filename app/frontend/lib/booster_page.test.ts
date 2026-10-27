import { afterEach, describe, expect, it, vi } from "vitest"
import { cardHref, celebrationMarked, newKey, readLayout, withPack } from "./booster_page"

const V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

describe("newKey", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("uses crypto.randomUUID where the context has it", () => {
    vi.stubGlobal("crypto", {
      randomUUID: () => "00000000-0000-4000-8000-000000000000",
      getRandomValues: () => new Uint8Array(16),
    })
    expect(newKey()).toBe("00000000-0000-4000-8000-000000000000")
  })

  it("builds a v4 UUID from random bytes without crypto.randomUUID", () => {
    vi.stubGlobal("crypto", { getRandomValues: (bytes: Uint8Array) => bytes.fill(0xff) })
    expect(newKey()).toBe("ffffffff-ffff-4fff-bfff-ffffffffffff")
    vi.stubGlobal("crypto", { getRandomValues: (bytes: Uint8Array) => bytes.fill(0) })
    expect(newKey()).toBe("00000000-0000-4000-8000-000000000000")
  })

  it("gives the v4 shape for any bytes", () => {
    const random = globalThis.crypto
    vi.stubGlobal("crypto", { getRandomValues: (bytes: Uint8Array<ArrayBuffer>) => random.getRandomValues(bytes) })
    for (let draw = 0; draw < 20; draw++) expect(newKey()).toMatch(V4)
  })
})

describe("readLayout", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("is wide without a window", () => {
    expect(readLayout()).toBe("wide")
  })

  it("follows the two media queries", () => {
    const matching = (queries: string[]) => ({ matchMedia: (query: string) => ({ matches: queries.includes(query) }) })
    vi.stubGlobal("window", matching(["(max-width: 719px)", "(max-width: 899px)"]))
    expect(readLayout()).toBe("phone")
    vi.stubGlobal("window", matching(["(max-width: 899px)"]))
    expect(readLayout()).toBe("narrow")
    vi.stubGlobal("window", matching([]))
    expect(readLayout()).toBe("wide")
  })
})

describe("cardHref", () => {
  it("names the card's slug, the pack and the card's place in it, from 1", () => {
    expect(cardHref("/fr/cards/SLUG", "blue-depths", "tok3n", 0)).toBe("/fr/cards/blue-depths?pack=tok3n&slot=1")
    expect(cardHref("/en/cards/SLUG", "a b", "tok3n", 4)).toBe("/en/cards/a%20b?pack=tok3n&slot=5")
  })
})

describe("withPack", () => {
  it("names the pack in the screen's address, keeping the rest of it", () => {
    expect(withPack("https://gameble.test/fr/booster", "tok3n")).toBe("https://gameble.test/fr/booster?pack=tok3n")
    expect(withPack("https://gameble.test/fr/booster?pack=old&x=1#top", "tok3n")).toBe(
      "https://gameble.test/fr/booster?pack=tok3n&x=1#top",
    )
  })

  it("drops it for none", () => {
    expect(withPack("https://gameble.test/fr/booster?pack=old&x=1", null)).toBe("https://gameble.test/fr/booster?x=1")
    expect(withPack("https://gameble.test/fr/booster", null)).toBe("https://gameble.test/fr/booster")
  })
})

describe("the celebration mark", () => {
  it("is set with the pack on demand", () => {
    const href = withPack("https://gameble.test/fr/booster", "tok3n", true)
    expect(href).toBe("https://gameble.test/fr/booster?pack=tok3n&celebration=1")
    expect(celebrationMarked(href)).toBe(true)
    expect(celebrationMarked(withPack("https://gameble.test/fr/booster", "tok3n"))).toBe(false)
  })

  it("is kept while the pack stays named", () => {
    expect(withPack("https://gameble.test/fr/booster?pack=tok3n&celebration=1", "tok3n")).toBe(
      "https://gameble.test/fr/booster?pack=tok3n&celebration=1",
    )
  })

  it("is dropped with the pack", () => {
    const href = withPack("https://gameble.test/fr/booster?pack=tok3n&celebration=1&x=1", null)
    expect(href).toBe("https://gameble.test/fr/booster?x=1")
    expect(celebrationMarked(href)).toBe(false)
  })
})
