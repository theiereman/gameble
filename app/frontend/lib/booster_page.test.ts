import { afterEach, describe, expect, it, vi } from "vitest"
import { newKey, readLayout } from "./booster_page"

const V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

describe("newKey", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("uses crypto.randomUUID where the context has it", () => {
    vi.stubGlobal("crypto", { randomUUID: () => "00000000-0000-4000-8000-000000000000", getRandomValues: () => new Uint8Array(16) })
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
