import { describe, expect, it } from "vitest"
import cardStylesheet from "../styles/card.css?raw"
import collectionStylesheet from "../styles/collection.css?raw"
import tokensStylesheet from "../styles/tokens.css?raw"

const ruleBody = (stylesheet: string, selector: string, from = 0) => {
  const at = stylesheet.indexOf(`${selector} {`, from)
  if (at < 0) return ""
  const open = stylesheet.indexOf("{", at)
  return stylesheet.slice(open + 1, stylesheet.indexOf("}", open))
}

const px = (body: string, property: string) => {
  const match = body.match(new RegExp(`${property}:\\s*(\\d+)px;`))
  if (!match) throw new Error(`${property} is not set in px`)
  return Number(match[1])
}

const token = (property: string) => px(ruleBody(tokensStylesheet, ":root"), property)

const evenFloor = (value: number) => 2 * Math.floor(value / 2)

const CONTAINER_SMALL = "@container (width < 140px)"
const PHONE = "@media (max-width: 719px)"

const gridCard = ruleBody(cardStylesheet, ".card--grid")
const smallGridCard = ruleBody(cardStylesheet, ".card--grid", cardStylesheet.indexOf(CONTAINER_SMALL))

const layout = (width: number) => {
  const small = width < 140
  const value = (property: string) =>
    small && smallGridCard.includes(`${property}:`) ? px(smallGridCard, property) : px(gridCard, property)
  const inset = 2 * (value("--card-frame") + value("--card-padding"))
  return {
    layout: small ? "small" : "medium",
    art: {
      width: width - inset,
      height: evenFloor(
        1.5 * width - inset - 3 * value("--card-gap") - value("--card-band-height")
          - value("--card-line-height") - value("--card-rarity-line-height"),
      ),
    },
  }
}

const MIN = token("--space-grid-card-min")
const MAX = token("--space-grid-card-max")
const GAP = token("--space-grid-gap-columns")

const fill = (gridWidth: number) => {
  const columns = Math.floor((gridWidth + GAP) / (MIN + GAP))
  const card = evenFloor(Math.min((gridWidth - (columns - 1) * GAP) / columns, MAX))
  return { columns, card }
}

describe("the grid card", () => {
  it("takes its slot's width, 1.5 times as tall, its art box even and what the rest leaves", () => {
    expect(gridCard).toContain("--card-width: 100cqi;")
    expect(gridCard).toContain("--card-height: calc(1.5 * var(--card-width));")
    expect(gridCard).toContain("--card-art-width: calc(var(--card-width) - var(--card-inset));")
    const artHeight = gridCard.slice(gridCard.indexOf("--card-art-height:"))
    expect(artHeight).toMatch(/^--card-art-height: round\(down,/)
    for (const term of [
      "var(--card-height)",
      "var(--card-inset)",
      "3 * var(--card-gap)",
      "var(--card-band-height)",
      "var(--card-line-height)",
      "var(--card-rarity-line-height)",
    ]) {
      expect(artHeight).toContain(term)
    }
    expect(artHeight).toMatch(/2px\);/)
  })

  it("is exactly the medium card at 160px and has the small card's layout at 112px", () => {
    const medium = ruleBody(cardStylesheet, ".card--m")
    const small = ruleBody(cardStylesheet, ".card--s")
    expect(layout(160)).toEqual({
      layout: "medium",
      art: { width: px(medium, "--card-art-width"), height: px(medium, "--card-art-height") },
    })
    expect(layout(112)).toEqual({
      layout: "small",
      art: { width: px(small, "--card-art-width"), height: px(small, "--card-art-height") },
    })
    for (const property of ["--card-frame", "--card-padding", "--card-line-height", "--card-rarity-line-height"]) {
      expect(px(gridCard, property)).toBe(px(medium, property))
      expect(px(smallGridCard, property)).toBe(px(small, property))
    }
    expect(gridCard).toContain("--card-title-font: var(--font-card-title-m);")
    expect(smallGridCard).toContain("--card-title-font: var(--font-card-title-s);")
  })

  it("hides the publisher under 140px", () => {
    const container = cardStylesheet.indexOf(CONTAINER_SMALL)
    expect(container).toBeGreaterThan(-1)
    expect(ruleBody(cardStylesheet, ".card--grid .card__publisher", container)).toContain("display: none")
  })
})

describe("the grid of every card", () => {
  const filling = ruleBody(collectionStylesheet, ".collection-grid--fill")
  const slot = ruleBody(collectionStylesheet, ".collection-grid--fill > .collection-slot")

  it("fills its row with columns of at least the smallest card", () => {
    expect(filling).toContain("grid-template-columns: repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr));")
    expect(MIN).toBe(120)
    expect(MAX).toBe(170)
  })

  it("sizes each slot to its column, even and capped, as a size container", () => {
    expect(slot).toContain("box-sizing: content-box;")
    expect(slot).toContain("width: round(down, min(100%, var(--space-grid-card-max)), 2px);")
    expect(slot).toContain("aspect-ratio: 2 / 3;")
    expect(slot).toContain("min-height: 0;")
    expect(slot).toContain("container-type: inline-size;")
    const faces = ruleBody(
      collectionStylesheet,
      ".collection-grid--fill > .collection-slot > .card-link,\n.collection-grid--fill .missing-slot",
    )
    expect(faces).toContain("width: 100cqi;")
    expect(faces).toContain("height: calc(1.5 * 100cqi);")
  })

  it("keeps two medium cards a row on the phone", () => {
    const phone = collectionStylesheet.indexOf(PHONE)
    expect(phone).toBeGreaterThan(collectionStylesheet.indexOf(".collection-grid--fill {"))
    expect(ruleBody(collectionStylesheet, ".collection-grid", phone)).toContain(
      "grid-template-columns: repeat(2, var(--card-m-width));",
    )
    const phoneCard = evenFloor(Math.min(px(ruleBody(cardStylesheet, ":root"), "--card-m-width"), MAX))
    expect(phoneCard).toBe(160)
    expect(layout(phoneCard).layout).toBe("medium")
  })

  it.each([
    { name: "an 800px window", gridWidth: 752, columns: 5, card: 136, cardLayout: "small" },
    { name: "1280px and up", gridWidth: 972, columns: 7, card: 124, cardLayout: "small" },
    { name: "a medium width", gridWidth: 780, columns: 5, card: 142, cardLayout: "medium" },
  ])("$name: $columns columns of $card px, $cardLayout layout", ({ gridWidth, columns, card, cardLayout }) => {
    const grid = fill(gridWidth)
    expect(grid).toEqual({ columns, card })
    expect(layout(grid.card).layout).toBe(cardLayout)
    const used = grid.columns * grid.card + (grid.columns - 1) * GAP
    expect(used).toBeLessThanOrEqual(gridWidth)
    expect(gridWidth - used).toBeLessThan(grid.card + GAP)
  })
})
