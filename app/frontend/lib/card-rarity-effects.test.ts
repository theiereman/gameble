import { describe, expect, it } from "vitest"
import boosterLayoutsStylesheet from "../styles/booster-layouts.css?raw"
import boosterStylesheet from "../styles/booster.css?raw"
import cardDetailStylesheet from "../styles/card-detail.css?raw"
import cardRarityEffectsStylesheet from "../styles/card-rarity-effects.css?raw"
import hubStylesheet from "../styles/hub.css?raw"

const rule = (stylesheet: string, selector: string) => {
  const at = stylesheet.indexOf(`${selector} {`)
  return at < 0 ? undefined : stylesheet.slice(at, stylesheet.indexOf("}", at))
}

const ruleBody = (stylesheet: string, selector: string) => {
  const at = stylesheet.indexOf(selector)
  if (at < 0) return undefined
  const open = stylesheet.indexOf("{", at)
  if (open < 0) return undefined
  const close = stylesheet.indexOf("}", open)
  return close < 0 ? undefined : stylesheet.slice(open + 1, close)
}

describe("the shared card rarity effects", () => {
  it("paints epic purple and legendary gold rays, large in the zoom", () => {
    expect(rule(cardRarityEffectsStylesheet, ".card-rays")).toContain("repeating-conic-gradient")
    expect(rule(cardRarityEffectsStylesheet, ".card-rays--epic")).toContain("var(--color-rarity-epique)")
    expect(rule(cardRarityEffectsStylesheet, ".card-rays--legendary")).toContain("var(--color-rarity-legendaire)")
    expect(rule(cardRarityEffectsStylesheet, ".card-rays--large")).toContain("--card-rays-size: 520px")
  })

  it("floats the wrapper while the card keeps its own transform, over a breathing shadow", () => {
    expect(rule(cardRarityEffectsStylesheet, ".card-float")).toContain("animation: card-idle-float 14s ease-in-out infinite")
    expect(cardRarityEffectsStylesheet).toContain("--idle-float-max")
    expect(rule(cardRarityEffectsStylesheet, ".card-ground")).toContain("animation: card-ground-breathe 14s ease-in-out infinite")
  })

  it("keeps booster reveal, zoom size and phone pile visually unchanged", () => {
    expect(rule(boosterStylesheet, ".booster-card[data-revealed] .booster-card__rays")).toContain("opacity: 1")
    expect(rule(boosterStylesheet, ".booster-card[data-revealed] .booster-card__rays")).toContain("card-rays-spin")
    expect(rule(boosterStylesheet, '.booster-card[data-revealed][data-tier="legendary"] .booster-card__rays')).toContain("animation-duration: 14s")
    expect(rule(boosterLayoutsStylesheet, '.booster-zoom[data-tier="legendary"] .booster-zoom__rays')).toContain("var(--color-rarity-legendaire)")
  })

  it("clips rays horizontally at wide outer boundaries, leaving ray margin visible", () => {
    for (const selector of [".card-detail__stage", ".public-card__stage", ".hub-showcase__stage"]) {
      expect(ruleBody(cardRarityEffectsStylesheet, selector)).toContain("overflow-x: clip")
    }
    for (const selector of [".card-detail__stage", ".public-card__stage"]) {
      expect(ruleBody(cardDetailStylesheet, selector)).toContain("min-width: min(340px, 100%)")
    }
    expect(ruleBody(hubStylesheet, ".hub-showcase__stage")).toContain("align-self: stretch")
    expect(ruleBody(cardDetailStylesheet, ".card-detail__nav")).toContain("z-index: 1")
  })

  it("stops every loop under reduced motion but keeps card rays visible", () => {
    for (const prefix of ['html[data-motion="reduced"]', 'html:not([data-motion="full"])']) {
      expect(rule(cardRarityEffectsStylesheet, `${prefix} .card-rays`)).toContain("animation: none")
      expect(rule(cardRarityEffectsStylesheet, `${prefix} .card-float`)).toContain("animation: none")
      expect(rule(cardRarityEffectsStylesheet, `${prefix} .card-ground`)).toContain("animation: none")
    }
    const reducedAt = boosterLayoutsStylesheet.lastIndexOf('html[data-motion="reduced"] .booster-card__rays')
    expect(reducedAt).toBeGreaterThan(-1)
    const reducedHide = boosterLayoutsStylesheet.slice(reducedAt)
    expect(reducedHide.slice(0, reducedHide.indexOf("}"))).toContain("display: none")
  })
})
