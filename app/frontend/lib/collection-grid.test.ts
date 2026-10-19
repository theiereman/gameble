import { describe, expect, it } from "vitest"
import cardStylesheet from "../styles/card.css?raw"
import cardDetailStylesheet from "../styles/card-detail.css?raw"
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

const WIDE = "@media (min-width: 1180px)"
const MEDIUM = "@media (min-width: 900px)"
const STACKED = "@media (min-width: 720px) and (max-width: 899px)"

const pageGutter = (property: string) => {
  const match = ruleBody(tokensStylesheet, ":root").match(new RegExp(`${property}:\\s*\\d+px (\\d+)px`))
  if (!match) throw new Error(`${property} has no inline padding`)
  return Number(match[1])
}

const detailColumn = (media: string) => {
  const results = ruleBody(collectionStylesheet, ".collection-results", collectionStylesheet.indexOf(media))
  const match = results.match(/grid-template-columns: minmax\(0, 1fr\) (\d+)px;/)
  if (!match) throw new Error(`no detail column under ${media}`)
  return Number(match[1])
}

const REPORT = Number(ruleBody(collectionStylesheet, ".collection").match(/grid-template-columns: (\d+)px minmax\(0, 1fr\);/)?.[1])

const WIDE_GRID =
  1280 - 2 * pageGutter("--space-page-padding-wide") - REPORT - token("--space-column-gap-wide")
  - detailColumn(WIDE) - token("--space-column-gap-wide")

const MEDIUM_GRID = 1024 - 2 * pageGutter("--space-page-padding-medium") - detailColumn(MEDIUM) - token("--space-column-gap-medium")

const STACKED_GRID = 800 - 2 * pageGutter("--space-page-padding-medium")

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

  it("fills its row with columns of at least the smallest medium card", () => {
    expect(filling).toContain("grid-template-columns: repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr));")
    expect(MIN).toBe(140)
    expect(MAX).toBe(170)
    expect(layout(MIN).layout).toBe("medium")
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
    { name: "an 800px window, the detail under the grid", gridWidth: STACKED_GRID, columns: 4, card: 170, cardLayout: "medium" },
    { name: "1280px and up, beside the RAPPORT and the detail", gridWidth: WIDE_GRID, columns: 3, card: 170, cardLayout: "medium" },
    { name: "a 1024px window, beside the detail", gridWidth: MEDIUM_GRID, columns: 4, card: 148, cardLayout: "medium" },
    { name: "a medium width", gridWidth: 780, columns: 5, card: 142, cardLayout: "medium" },
  ])("$name: $columns columns of $card px, $cardLayout layout", ({ gridWidth, columns, card, cardLayout }) => {
    const grid = fill(gridWidth)
    expect(grid).toEqual({ columns, card })
    expect(layout(grid.card).layout).toBe(cardLayout)
    const used = grid.columns * grid.card + (grid.columns - 1) * GAP
    expect(used).toBeLessThanOrEqual(gridWidth)
    expect(gridWidth - used).toBeLessThan(grid.card + GAP)
  })

  it("gives every desktop grid width the medium face", () => {
    const classicScrollbar = 15
    const narrowest = WIDE_GRID - (1280 - 1180) - classicScrollbar
    const widest = 1280 - 2 * pageGutter("--space-page-padding-wide")
    for (let gridWidth = narrowest; gridWidth <= widest; gridWidth++) {
      expect(layout(fill(gridWidth).card).layout).toBe("medium")
    }
  })
})

describe("a set's album grid", () => {
  it("spans its header's full width, each card centred in its column", () => {
    expect(collectionStylesheet).not.toContain(".set-album__grid {")
    expect(ruleBody(collectionStylesheet, ".set-album__grid > .collection-slot")).toContain("justify-self: center;")
    expect(collectionStylesheet.indexOf(".set-album__grid > .collection-slot {")).toBeGreaterThan(
      collectionStylesheet.indexOf(".collection-grid--fill > .collection-slot {"),
    )
  })

  it.each([
    { name: "1280px and up", gridWidth: 1280 - 2 * pageGutter("--space-page-padding-wide"), columns: 7, card: 160 },
    { name: "1280px beside a classic scrollbar", gridWidth: 1280 - 15 - 2 * pageGutter("--space-page-padding-wide"), columns: 7, card: 156 },
    { name: "a 1024px window", gridWidth: 1024 - 2 * pageGutter("--space-page-padding-medium"), columns: 6, card: 148 },
  ])("$name: $columns columns of $card px, medium layout", ({ gridWidth, columns, card }) => {
    const grid = fill(gridWidth)
    expect(grid).toEqual({ columns, card })
    expect(layout(grid.card).layout).toBe("medium")
    const spare = (gridWidth - (columns - 1) * GAP) / columns - grid.card
    expect(spare / 2).toBeLessThan(1)
  })
})

describe("the card detail beside the grid", () => {
  const needed = () => 2 * token("--space-touch-min") + 2 * token("--space-2") + px(ruleBody(cardStylesheet, ".card--l"), "--card-width")

  it("is a 340px column from 1180px and a 300px one from 900px, so the grid is 592px and 644px wide", () => {
    expect(REPORT).toBe(220)
    expect(detailColumn(WIDE)).toBe(340)
    expect(detailColumn(MEDIUM)).toBe(300)
    expect(WIDE_GRID).toBe(592)
    expect(MEDIUM_GRID).toBe(644)
    expect(ruleBody(collectionStylesheet, ".collection-results", collectionStylesheet.indexOf(WIDE))).toContain(
      "column-gap: var(--space-column-gap-wide);",
    )
    expect(ruleBody(collectionStylesheet, ".collection-results", collectionStylesheet.indexOf(MEDIUM))).toContain(
      "column-gap: var(--space-column-gap-medium);",
    )
  })

  it("stays near the top of the viewport beside the grid, scrolling inside itself without clipping its brackets", () => {
    const detail = ruleBody(collectionStylesheet, ".collection-detail", collectionStylesheet.indexOf(MEDIUM))
    expect(detail).toContain("position: sticky;")
    expect(detail).toContain("top: var(--space-5);")
    expect(detail).toContain("max-height: calc(100dvh - 2 * var(--space-5));")
    expect(detail).toContain("overflow: hidden auto;")
    expect(detail).toContain("margin: calc(-1 * var(--detail-room));")
    expect(detail).toContain("padding: var(--detail-room);")
    const room = ruleBody(collectionStylesheet, ".collection-detail").match(/--detail-room: var\((--space-\d)\);/)?.[1]
    const brackets = ruleBody(tokensStylesheet, ":root").match(/--corner-brackets-offset: -(\d+)px;/)?.[1]
    expect(room).toBeDefined()
    expect(token(room!)).toBeGreaterThanOrEqual(Number(brackets))
    expect(ruleBody(collectionStylesheet, ".collection-results")).toContain("align-items: start;")
  })

  it("shows under the grid from 720px only once a card is opened, and never on the phone", () => {
    expect(ruleBody(collectionStylesheet, ".collection-detail")).toContain("display: none;")
    expect(ruleBody(collectionStylesheet, ".collection-detail:has(> .card-detail)", collectionStylesheet.indexOf(STACKED))).toContain(
      "display: block;",
    )
  })

  it("puts ◀ ▶ under the card when the panel is narrower than ◀ card ▶", () => {
    const nav = ruleBody(cardDetailStylesheet, ".card-detail__nav")
    expect(ruleBody(cardDetailStylesheet, ".card-detail__stage")).toContain("gap: var(--space-2);")
    expect(nav).toContain("width: var(--space-touch-min);")
    expect(nav).toContain("height: 64px;")
    expect(px(ruleBody(cardDetailStylesheet, ".card-detail__back"), "width")).toBe(px(ruleBody(cardStylesheet, ".card--l"), "--card-width"))
    expect(needed()).toBe(304)
    const narrow = collectionStylesheet.indexOf(`@container (width < ${needed()}px)`)
    expect(narrow).toBeGreaterThan(-1)
    const stage = ruleBody(collectionStylesheet, ".collection-detail .card-detail__stage", narrow)
    expect(stage).toContain("display: grid;")
    expect(stage).toMatch(/grid-template-areas:\s*"card card"\s*"previous next";/)
  })

  it("fits ◀ card ▶ in the 340px column beside a thin scrollbar, not in the 300px one", () => {
    const padding = ruleBody(collectionStylesheet, ".collection-detail > .card-detail").match(/padding-inline: var\((--space-\d)\);/)?.[1]
    expect(padding).toBeDefined()
    const thinScrollbar = 11
    expect(detailColumn(WIDE) - thinScrollbar - 2 * token(padding!)).toBeGreaterThanOrEqual(needed())
    expect(detailColumn(MEDIUM) - 2 * token(padding!)).toBeLessThan(needed())
    expect(ruleBody(collectionStylesheet, ".collection-detail", collectionStylesheet.indexOf(MEDIUM))).toContain("scrollbar-width: thin;")
  })

  it("frames the selected card with a steady 3px accent line inside the slot's bleed", () => {
    const frame = ruleBody(collectionStylesheet, '.collection-slot > .card-link[aria-current="true"]::after')
    expect(frame).toContain("box-shadow: inset 0 0 0 3px var(--color-accent);")
    expect(frame).toContain("inset: calc(-1 * var(--space-2) - 3px);")
    expect(frame).not.toContain("animation")
    const bleed = ruleBody(collectionStylesheet, ".collection").match(/--slot-bleed: var\((--space-\d)\);/)?.[1]
    expect(bleed).toBeDefined()
    expect(token("--space-2") + 3).toBeLessThanOrEqual(token(bleed!))
  })
})
