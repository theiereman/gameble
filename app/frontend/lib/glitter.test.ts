import { describe, expect, it } from "vitest"
import boosterLayoutsStylesheet from "../styles/booster-layouts.css?raw"
import boosterStylesheet from "../styles/booster.css?raw"
import cardStylesheet from "../styles/card.css?raw"
import { DEFAULT_SEED, FLASH_REACH, attachGlitter, flakeField, flakeFlash, flakeLevel, glitterSeed } from "./glitter"

// An element stand-in: a class name, attributes, custom properties and children.
class FakeElement {
  className = ""
  attributes = new Set<string>()
  properties = new Map<string, string>()
  children: FakeElement[] = []
  style = { setProperty: (name: string, value: string) => this.properties.set(name, value) }

  constructor(readonly ownerDocument: { createElement: () => FakeElement }) {}

  append(...children: FakeElement[]) {
    this.children.push(...children)
  }

  replaceChildren(...children: FakeElement[]) {
    this.children = children
  }

  toggleAttribute(name: string, force: boolean) {
    if (force) this.attributes.add(name)
    else this.attributes.delete(name)
  }
}

function container(): FakeElement {
  const document = { createElement: (): FakeElement => new FakeElement(document) }
  return new FakeElement(document)
}

describe("flakeField", () => {
  it("draws the same flakes for a seed, and others for another seed", () => {
    expect(flakeField(42, 200, 300)).toEqual(flakeField(42, 200, 300))
    expect(flakeField(43, 200, 300)).not.toEqual(flakeField(42, 200, 300))
  })

  it("scatters as many flakes per area at every size", () => {
    expect(flakeField(1, 200, 300)).toHaveLength(28)
    expect(flakeField(1, 240, 360)).toHaveLength(40)
    expect(flakeField(1, 112, 168)).toHaveLength(9)
  })

  it("puts each flake on the 2px grid, clear of the edges, facing within reach of a tilt", () => {
    for (const flake of flakeField(7, 160, 240)) {
      expect(flake.x % 2).toBe(0)
      expect(flake.y % 2).toBe(0)
      expect(flake.x).toBeGreaterThanOrEqual(8)
      expect(flake.x).toBeLessThanOrEqual(160 - 8)
      expect(flake.y).toBeGreaterThanOrEqual(8)
      expect(flake.y).toBeLessThanOrEqual(240 - 8)
      expect(Math.abs(flake.nx)).toBeLessThanOrEqual(0.45)
      expect(Math.abs(flake.ny)).toBeLessThanOrEqual(0.45)
      expect(flake.period).toBeGreaterThanOrEqual(2.4)
      expect(flake.period).toBeLessThan(6)
      expect(flake.delay).toBeLessThanOrEqual(0)
      expect(flake.delay).toBeGreaterThan(-6)
    }
  })

  it("makes about a third of the flakes crosses, mostly white ones", () => {
    const field = flakeField(3, 2000, 3000)
    const share = (count: number) => count / field.length
    expect(share(field.filter((flake) => flake.cross).length)).toBeGreaterThan(0.3)
    expect(share(field.filter((flake) => flake.cross).length)).toBeLessThan(0.4)
    expect(share(field.filter((flake) => flake.colour === "white").length)).toBeGreaterThan(0.38)
    expect(new Set(field.map((flake) => flake.colour))).toEqual(new Set(["white", "gold", "violet", "blue"]))
  })
})

describe("flakeFlash", () => {
  const flake = { nx: 0.1, ny: -0.2 }

  it("is full when the tilt faces the flake's normal, and nothing beyond its reach", () => {
    expect(flakeFlash(flake, 0.1, -0.2)).toBe(1)
    expect(flakeFlash(flake, 0.1 + FLASH_REACH, -0.2)).toBeCloseTo(0)
    expect(flakeFlash(flake, 0.4, 0.3)).toBe(0)
    expect(flakeFlash(flake, 0.1 + FLASH_REACH / 2, -0.2)).toBeCloseTo(0.5 ** 1.5)
  })
})

describe("flakeLevel", () => {
  it("steps from half to full brightness in quarters", () => {
    expect(flakeLevel(0)).toBe(0.5)
    expect(flakeLevel(0.1)).toBe(0.5)
    expect(flakeLevel(0.3)).toBe(0.625)
    expect(flakeLevel(0.6)).toBe(0.75)
    expect(flakeLevel(1)).toBe(1)
  })
})

describe("attachGlitter", () => {
  it("draws the flakes, lights the one the tilt faces, and takes them away", () => {
    const element = container()
    const glitter = attachGlitter(element as unknown as HTMLElement, { seed: 5, width: 200, height: 300 })
    const field = flakeField(5, 200, 300)

    expect(element.children).toHaveLength(28)
    const [first] = element.children
    expect(first.className).toBe(`card__flake card__flake--${field[0].colour}${field[0].cross ? " card__flake--cross" : ""}`)
    expect(first.properties.get("left")).toBe(`${field[0].x}px`)
    expect(first.properties.get("top")).toBe(`${field[0].y}px`)
    expect(first.properties.get("--flake-period")).toBe(`${field[0].period}s`)
    expect(first.properties.get("--flake-delay")).toBe(`${field[0].delay}s`)
    expect(first.children.map((glint) => glint.className)).toEqual(["card__flake-glint"])

    glitter.update(field[0].nx, field[0].ny)
    expect(first.attributes.has("data-flash")).toBe(true)
    expect(first.properties.get("--flake-level")).toBe("1")

    glitter.update(5, 5)
    expect(element.children.some((flake) => flake.attributes.has("data-flash"))).toBe(false)
    expect(element.children.every((flake) => flake.properties.get("--flake-level") === "0.5")).toBe(true)

    glitter.detach()
    expect(element.children).toHaveLength(0)
  })
})

describe("glitterSeed", () => {
  it("reads the face's seed, and falls back to the default one", () => {
    expect(glitterSeed("2000042")).toBe(2000042)
    expect(glitterSeed(undefined)).toBe(DEFAULT_SEED)
    expect(glitterSeed("")).toBe(DEFAULT_SEED)
  })
})

describe("the glitter's stylesheet", () => {
  const rule = (stylesheet: string, selector: string) => {
    const at = stylesheet.indexOf(`${selector} {`)
    return at < 0 ? undefined : stylesheet.slice(at, stylesheet.indexOf("}", at))
  }

  it("twinkles a flake only while the face is in view and the flake is not flashing", () => {
    expect(rule(cardStylesheet, ".card[data-in-view] :where(.card__flake:not([data-flash])) .card__flake-glint")).toContain("animation: card-glitter-twinkle")
    expect(rule(cardStylesheet, ".card__flake-glint")).toContain("opacity: 0.18")
  })

  it("keeps the flakes still and faint under reduced motion, chosen or from the system", () => {
    for (const selector of ['html[data-motion="reduced"] .card__flake .card__flake-glint', '  html:not([data-motion="full"]) .card__flake .card__flake-glint']) {
      const still = rule(cardStylesheet, selector)
      expect(still).toContain("animation: none")
      expect(still).toContain("opacity: 0.18")
    }
  })

  it("keeps a face-down booster card and a phone's lower cards still", () => {
    const faceDown = rule(boosterStylesheet, ".booster-card:not([data-revealed]) .card__flake-glint")
    expect(faceDown).toContain("animation: none")
    expect(faceDown).toContain("opacity: 0.18")
    const lower = rule(boosterLayoutsStylesheet, '.booster[data-layout="phone"] .booster-card:not([data-top]) .card__flake-glint')
    expect(lower).toContain("animation: none")
    expect(lower).toContain("opacity: 0.18")
    expect(rule(boosterLayoutsStylesheet, '.booster[data-layout="phone"] .booster-card:not([data-top]) .booster-card__rays')).not.toContain("opacity")
  })
})
