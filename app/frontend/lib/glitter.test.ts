import { describe, expect, it } from "vitest"
import booster from "../styles/booster.css?raw"
import boosterCanister from "../styles/booster-canister.css?raw"
import boosterCelebration from "../styles/booster-celebration.css?raw"
import boosterEffects from "../styles/booster-effects.css?raw"
import boosterLayouts from "../styles/booster-layouts.css?raw"
import boosterLayoutsTray from "../styles/booster-layouts-tray.css?raw"
import card from "../styles/card.css?raw"
import cardTiltEffects from "../styles/card-tilt-effects.css?raw"
import {
  DEFAULT_SEED,
  FLASH_REACH,
  TWINKLE_GROUPS,
  attachGlitter,
  flakeField,
  flakeFlash,
  flakeLevel,
  glitterSeed,
} from "./glitter"

const boosterStylesheet = booster + boosterCanister + boosterEffects + boosterCelebration
const boosterLayoutsStylesheet = boosterLayouts + boosterLayoutsTray

const cardStylesheet = card + cardTiltEffects

// An element stand-in: a class name, attributes, custom properties and
// children; a child appended elsewhere leaves its former parent.
class FakeElement {
  className = ""
  attributes = new Set<string>()
  properties = new Map<string, string>()
  children: FakeElement[] = []
  parent?: FakeElement
  style = { setProperty: (name: string, value: string) => this.properties.set(name, value) }

  constructor(readonly ownerDocument: { createElement: () => FakeElement }) {}

  append(...children: FakeElement[]) {
    for (const child of children) {
      child.parent?.remove(child)
      child.parent = this
      this.children.push(child)
    }
  }

  replaceChildren(...children: FakeElement[]) {
    for (const child of this.children) child.parent = undefined
    this.children = []
    this.append(...children)
  }

  remove(child: FakeElement) {
    this.children = this.children.filter((other) => other !== child)
    child.parent = undefined
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

const flakes = (seed: number, width: number, height: number) => flakeField(seed, width, height).flakes

describe("flakeField", () => {
  it("draws the same flakes, groups and rhythms for a seed, and others for another seed", () => {
    expect(flakeField(42, 200, 300)).toEqual(flakeField(42, 200, 300))
    expect(flakeField(43, 200, 300).flakes).not.toEqual(flakeField(42, 200, 300).flakes)
    expect(flakeField(43, 200, 300).groups).not.toEqual(flakeField(42, 200, 300).groups)
  })

  it("scatters as many flakes per area at every size", () => {
    expect(flakes(1, 200, 300)).toHaveLength(28)
    expect(flakes(1, 240, 360)).toHaveLength(40)
    expect(flakes(1, 112, 168)).toHaveLength(9)
  })

  it("gives every size three twinkle groups, each with its own rhythm, and puts every flake in one", () => {
    for (const [width, height] of [
      [112, 168],
      [160, 240],
      [240, 360],
    ]) {
      const field = flakeField(11, width, height)
      expect(field.groups).toHaveLength(TWINKLE_GROUPS)
      expect(TWINKLE_GROUPS).toBe(3)
      for (const { period, delay } of field.groups) {
        expect(period).toBeGreaterThanOrEqual(2.4)
        expect(period).toBeLessThan(6)
        expect(delay).toBeLessThanOrEqual(0)
        expect(delay).toBeGreaterThan(-6)
      }
      expect(new Set(field.groups.map(({ period }) => period)).size).toBe(TWINKLE_GROUPS)
      for (const flake of field.flakes) {
        expect(Number.isInteger(flake.group)).toBe(true)
        expect(flake.group).toBeGreaterThanOrEqual(0)
        expect(flake.group).toBeLessThan(TWINKLE_GROUPS)
        expect(flake).not.toHaveProperty("period")
        expect(flake).not.toHaveProperty("delay")
      }
    }
  })

  it("puts each flake on the 2px grid, clear of the edges, facing within reach of a tilt", () => {
    for (const flake of flakes(7, 160, 240)) {
      expect(flake.x % 2).toBe(0)
      expect(flake.y % 2).toBe(0)
      expect(flake.x).toBeGreaterThanOrEqual(8)
      expect(flake.x).toBeLessThanOrEqual(160 - 8)
      expect(flake.y).toBeGreaterThanOrEqual(8)
      expect(flake.y).toBeLessThanOrEqual(240 - 8)
      expect(Math.abs(flake.nx)).toBeLessThanOrEqual(0.45)
      expect(Math.abs(flake.ny)).toBeLessThanOrEqual(0.45)
    }
  })

  it("makes about a third of the flakes crosses, mostly white ones", () => {
    const field = flakes(3, 2000, 3000)
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
  const flakesIn = (element: FakeElement) => element.children.flatMap((group) => group.children)

  it("draws the flakes into their three twinkle groups, each carrying its rhythm", () => {
    for (const [width, height] of [
      [112, 168],
      [160, 240],
      [240, 360],
    ]) {
      const element = container()
      attachGlitter(element as unknown as HTMLElement, { seed: 5, width, height })
      const field = flakeField(5, width, height)

      expect(element.children.map((group) => group.className)).toEqual(Array(TWINKLE_GROUPS).fill("card__flake-group"))
      element.children.forEach((group, index) => {
        expect(group.properties.get("--flake-period")).toBe(`${field.groups[index].period}s`)
        expect(group.properties.get("--flake-delay")).toBe(`${field.groups[index].delay}s`)
        expect(group.children.every((flake) => flake.className.startsWith("card__flake "))).toBe(true)
        expect(group.children).toHaveLength(field.flakes.filter((flake) => flake.group === index).length)
      })
      expect(flakesIn(element)).toHaveLength(field.flakes.length)
      for (const flake of flakesIn(element)) {
        expect(flake.properties.has("--flake-period")).toBe(false)
        expect(flake.properties.has("--flake-delay")).toBe(false)
        expect(flake.children.every((glint) => glint.properties.size === 0)).toBe(true)
      }
    }
  })

  it("draws the same groups, membership and rhythms for a seed", () => {
    const draw = (seed: number) => {
      const element = container()
      attachGlitter(element as unknown as HTMLElement, { seed, width: 160, height: 240 })
      return element.children.map((group) => ({
        rhythm: [group.properties.get("--flake-period"), group.properties.get("--flake-delay")],
        flakes: group.children.map((flake) => [
          flake.className,
          flake.properties.get("left"),
          flake.properties.get("top"),
        ]),
      }))
    }
    expect(draw(9)).toEqual(draw(9))
    expect(draw(10)).not.toEqual(draw(9))
  })

  it("lights the flake the tilt faces outside its group, puts it back when the flash ends, and takes them all away", () => {
    const element = container()
    const glitter = attachGlitter(element as unknown as HTMLElement, { seed: 5, width: 200, height: 300 })
    const field = flakeField(5, 200, 300)
    const [first] = field.flakes
    const flake = element.children[first.group].children[0]

    expect(flake.className).toBe(`card__flake card__flake--${first.colour}${first.cross ? " card__flake--cross" : ""}`)
    expect(flake.properties.get("left")).toBe(`${first.x}px`)
    expect(flake.properties.get("top")).toBe(`${first.y}px`)
    expect(flake.children.map((glint) => glint.className)).toEqual(["card__flake-glint"])

    glitter.update(first.nx, first.ny)
    expect(flake.attributes.has("data-flash")).toBe(true)
    expect(flake.properties.get("--flake-level")).toBe("1")
    expect(flake.parent).toBe(element)
    expect(element.children[first.group].children).not.toContain(flake)
    expect(element.children.filter((child) => child.className === "card__flake-group")).toHaveLength(TWINKLE_GROUPS)

    glitter.update(5, 5)
    expect(element.children).toHaveLength(TWINKLE_GROUPS)
    expect(flake.parent).toBe(element.children[first.group])
    expect(flakesIn(element)).toHaveLength(28)
    expect(flakesIn(element).some((other) => other.attributes.has("data-flash"))).toBe(false)
    expect(flakesIn(element).every((other) => other.properties.get("--flake-level") === "0.5")).toBe(true)

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

  const twinkles = (stylesheet: string) => stylesheet.split("animation: card-glitter-twinkle").length - 1

  it("twinkles each flake group, and only while the face is in view", () => {
    expect(rule(cardStylesheet, ".card[data-in-view] :where(.card__flake-group)")).toContain(
      "animation: card-glitter-twinkle var(--flake-period) steps(1) var(--flake-delay) infinite",
    )
    expect(twinkles(cardStylesheet) + twinkles(boosterStylesheet) + twinkles(boosterLayoutsStylesheet)).toBe(1)
    expect(rule(cardStylesheet, ".card__flake-group")).toContain("opacity: 0.18")
    expect(rule(cardStylesheet, ".card__flake-glint")).not.toContain("opacity")
  })

  it("animates no flake and no glint", () => {
    const targetsAFlake = (selector: string) =>
      selector.split(",").some((part) => /\.card__flake(?!-group)/.test(part.trim().split(/\s+/).at(-1) ?? ""))
    const flakeRules = [cardStylesheet, boosterStylesheet, boosterLayoutsStylesheet]
      .flatMap((stylesheet) => [...stylesheet.matchAll(/([^{}]*)\{([^{}]*)\}/g)])
      .filter(([, selector]) => targetsAFlake(selector))
    expect(flakeRules.length).toBeGreaterThan(5)
    for (const [, selector, body] of flakeRules) expect(body, selector).not.toMatch(/animation:\s*(?!none)/)
  })

  it("keeps the flakes still and faint under reduced motion, chosen or from the system", () => {
    for (const prefix of ['html[data-motion="reduced"]', '  html:not([data-motion="full"])']) {
      expect(rule(cardStylesheet, `${prefix} .card__flake-group`)).toContain("animation: none")
      expect(rule(cardStylesheet, `${prefix} .card__flake[data-flash] .card__flake-glint`)).toContain("opacity: 0.18")
    }
  })

  it("keeps a face-down booster card and a phone's lower cards still", () => {
    for (const [stylesheet, card] of [
      [boosterStylesheet, ".booster-card:not([data-revealed])"],
      [boosterLayoutsStylesheet, '.booster[data-layout="phone"] .booster-card:not([data-top])'],
    ]) {
      expect(rule(stylesheet, `${card} .card__flake-group`)).toContain("animation: none")
      expect(rule(stylesheet, `${card} .card__flake[data-flash] .card__flake-glint`)).toContain("opacity: 0.18")
    }
    const lowerRays = rule(
      boosterLayoutsStylesheet,
      '.booster[data-layout="phone"] .booster-card:not([data-top]) .booster-card__rays',
    )
    expect(lowerRays).toContain("display: none")
    expect(lowerRays).not.toContain("opacity")
  })
})
