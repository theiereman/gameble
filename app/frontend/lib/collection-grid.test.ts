import { describe, expect, it } from "vitest"
import cardStylesheet from "../styles/card.css?raw"
import collectionStylesheet from "../styles/collection.css?raw"
import shellStylesheet from "../styles/shell.css?raw"
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
const PHONE_NARROW = "@media (max-width: 371px)"
const CLASSIC_SCROLLBAR = 15

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
const GAP = token("--space-grid-gap-columns")

const share = (gridWidth: number, columns: number, gap: number) => {
  const column = (gridWidth - (columns - 1) * gap) / columns
  const card = evenFloor(column)
  return { columns, card, spare: column - card }
}

const fill = (gridWidth: number, gap = GAP) => share(gridWidth, Math.floor((gridWidth + gap) / (MIN + gap)), gap)

const pageGutter = (property: string) => {
  const match = ruleBody(tokensStylesheet, ":root").match(new RegExp(`${property}:\\s*\\d+px (?:(\\d+)px|var\\((--[\\w-]+)\\))`))
  if (!match) throw new Error(`${property} has no inline padding`)
  return match[2] ? token(match[2]) : Number(match[1])
}

const REPORT = Number(ruleBody(collectionStylesheet, ".collection").match(/grid-template-columns: (\d+)px minmax\(0, 1fr\);/)?.[1])

const WIDE_PAGE = 1280 - 2 * pageGutter("--space-page-padding-wide")
const CARDS_WIDE = WIDE_PAGE - REPORT - token("--space-column-gap-wide")
const mediumPage = (window: number) => window - 2 * pageGutter("--space-page-padding-medium")
const phonePage = (window: number) => window - 2 * pageGutter("--space-page-padding-phone")

const narrowPhoneGap = () => {
  const gap = ruleBody(collectionStylesheet, ".collection-grid", collectionStylesheet.indexOf(PHONE_NARROW))
    .match(/column-gap: var\((--space-\d)\);/)?.[1]
  if (!gap) throw new Error("the narrow phone grid has no gap of its own")
  return token(gap)
}

const phone = (window: number, scrollbar = 0) =>
  share(phonePage(window) - scrollbar, 2, window <= 371 ? narrowPhoneGap() : GAP)

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

  it("fills its row with columns of at least the smallest medium card, with no largest card", () => {
    expect(filling).toContain("grid-template-columns: repeat(auto-fill, minmax(var(--space-grid-card-min), 1fr));")
    expect(MIN).toBe(140)
    expect(layout(MIN).layout).toBe("medium")
    expect(tokensStylesheet).not.toContain("--space-grid-card-max")
    expect(collectionStylesheet).not.toContain("--space-grid-card-max")
  })

  it("sizes each slot to its column, rounded down to an even pixel and centred in it, as a size container", () => {
    expect(slot).toContain("box-sizing: content-box;")
    expect(slot).toContain("width: round(down, 100%, 2px);")
    expect(slot).toContain("justify-self: center;")
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

  it("shares the phone's width between two columns, the gap 8px on narrow phones", () => {
    const phoneAt = collectionStylesheet.indexOf(PHONE)
    expect(phoneAt).toBeGreaterThan(collectionStylesheet.indexOf(".collection-grid--fill {"))
    const phoneGrid = ruleBody(collectionStylesheet, ".collection-grid", phoneAt)
    expect(phoneGrid).toContain("grid-template-columns: repeat(2, minmax(0, 1fr));")
    expect(phoneGrid).not.toContain("justify-content")
    expect(collectionStylesheet.indexOf(PHONE_NARROW)).toBeGreaterThan(phoneAt)
    expect(narrowPhoneGap()).toBe(8)
  })

  it("is 964px wide beside the RAPPORT at 1280px", () => {
    expect(REPORT).toBe(220)
    expect(CARDS_WIDE).toBe(964)
  })

  it.each([
    { name: "1280px and up, beside the RAPPORT", gridWidth: CARDS_WIDE, columns: 6, card: 146 },
    { name: "1280px beside a classic scrollbar", gridWidth: CARDS_WIDE - CLASSIC_SCROLLBAR, columns: 6, card: 144 },
    { name: "a 1024px window", gridWidth: mediumPage(1024), columns: 6, card: 148 },
    { name: "a 1024px window beside a classic scrollbar", gridWidth: mediumPage(1024) - CLASSIC_SCROLLBAR, columns: 6, card: 144 },
    { name: "an 800px window", gridWidth: mediumPage(800), columns: 4, card: 174 },
    { name: "an 800px window beside a classic scrollbar", gridWidth: mediumPage(800) - CLASSIC_SCROLLBAR, columns: 4, card: 170 },
  ])("$name: $columns columns of $card px, each under 1px from its column's edges", ({ gridWidth, columns, card }) => {
    const grid = fill(gridWidth)
    expect({ columns: grid.columns, card: grid.card }).toEqual({ columns, card })
    expect(layout(grid.card).layout).toBe("medium")
    expect(grid.spare).toBeLessThan(2)
  })

  it.each([
    { name: "a 390px phone", grid: phone(390), card: 166 },
    { name: "a 390px phone beside a classic scrollbar", grid: phone(390, CLASSIC_SCROLLBAR), card: 158 },
    { name: "a 360px phone", grid: phone(360), card: 156 },
  ])("$name: two cards of $card px filling the page", ({ grid, card }) => {
    expect(grid.card).toBe(card)
    expect(layout(grid.card).layout).toBe("medium")
    expect(grid.spare).toBeLessThan(2)
  })

  it("gives every tablet and desktop grid width the medium face", () => {
    const narrowest = mediumPage(720) - CLASSIC_SCROLLBAR
    expect(narrowest).toBe(649)
    for (let gridWidth = narrowest; gridWidth <= WIDE_PAGE; gridWidth++) {
      const grid = fill(gridWidth)
      expect(grid.card).toBeGreaterThanOrEqual(MIN)
      expect(layout(grid.card).layout).toBe("medium")
      expect(grid.spare).toBeLessThan(2)
    }
  })
})

describe("a set's album grid", () => {
  it("spans its header's full width under the slot rule of every fill grid", () => {
    expect(collectionStylesheet).not.toContain(".set-album__grid {")
    expect(collectionStylesheet).not.toContain(".set-album__grid > .collection-slot")
  })

  it.each([
    { name: "1280px and up", gridWidth: WIDE_PAGE, columns: 7, card: 160 },
    { name: "1280px beside a classic scrollbar", gridWidth: WIDE_PAGE - CLASSIC_SCROLLBAR, columns: 7, card: 156 },
  ])("$name: $columns columns of $card px, each under 1px from its column's edges", ({ gridWidth, columns, card }) => {
    const grid = fill(gridWidth)
    expect({ columns: grid.columns, card: grid.card }).toEqual({ columns, card })
    expect(layout(grid.card).layout).toBe("medium")
    expect(grid.spare).toBeLessThan(2)
  })
})

describe("the top bar", () => {
  it("takes the page's inline gutter under 1180px", () => {
    expect(token("--space-gutter-medium")).toBe(28)
    expect(ruleBody(tokensStylesheet, ":root")).toContain("--space-page-padding-medium: 24px var(--space-gutter-medium) 32px;")
    expect(pageGutter("--space-page-padding-medium")).toBe(28)
    const medium = shellStylesheet.indexOf("@media (max-width: 1179px)")
    expect(medium).toBeGreaterThan(-1)
    const nextMedia = shellStylesheet.indexOf("@media", medium + 1)
    expect(shellStylesheet.indexOf(".main {", medium)).toBeLessThan(nextMedia)
    expect(ruleBody(shellStylesheet, ".main", medium)).toContain("padding: var(--space-page-padding-medium);")
    expect(shellStylesheet.indexOf(".top-bar__inner {", medium)).toBeLessThan(nextMedia)
    expect(ruleBody(shellStylesheet, ".top-bar__inner", medium)).toContain("padding-inline: var(--space-gutter-medium);")
  })
})
