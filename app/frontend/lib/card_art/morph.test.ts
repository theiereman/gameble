import { describe, expect, it } from "vitest"
import { keepsArtThroughMorph } from "./morph"

function element(attributes: Record<string, string>) {
  return {
    getAttributeNames: () => Object.keys(attributes),
    getAttribute: (name: string) => attributes[name] ?? null,
  }
}

const SERVED = {
  "data-controller": "card-art",
  "data-card-art-url-value": "https://cdn.test/a.jpg",
  "data-card-art-width-value": "120",
  "data-card-art-height-value": "180",
}

describe("keepsArtThroughMorph", () => {
  it("keeps a drawn art when the refreshed page serves the same one", () => {
    expect(keepsArtThroughMorph(element({ ...SERVED, "data-art": "drawn" }), element(SERVED))).toBe(true)
  })

  it("lets the morph through when the refreshed page serves another cover or size", () => {
    const drawn = element({ ...SERVED, "data-art": "drawn" })
    expect(
      keepsArtThroughMorph(drawn, element({ ...SERVED, "data-card-art-url-value": "https://cdn.test/b.jpg" })),
    ).toBe(false)
    expect(keepsArtThroughMorph(drawn, element({ ...SERVED, "data-card-art-fluid-value": "true" }))).toBe(false)
  })

  it("lets the morph through to try again an art that failed", () => {
    expect(keepsArtThroughMorph(element({ ...SERVED, "data-art": "failed" }), element(SERVED))).toBe(false)
  })
})
