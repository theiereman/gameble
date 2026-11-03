import { describe, expect, it } from "vitest"
import boosterLayouts from "../styles/booster-layouts.css?raw"
import boosterLayoutsTray from "../styles/booster-layouts-tray.css?raw"
import cardDetail from "../styles/card-detail.css?raw"
import cardDetailPublic from "../styles/card-detail-public.css?raw"
import cardDetailStepping from "../styles/card-detail-stepping.css?raw"
import cardRarityEffectsStylesheet from "../styles/card-rarity-effects.css?raw"
import hubStylesheet from "../styles/hub.css?raw"

const boosterLayoutsStylesheet = boosterLayouts + boosterLayoutsTray

const cardDetailStylesheet = cardDetail + cardDetailStepping + cardDetailPublic

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
  it("clips the rays sideways at each stage and fades them within the narrow ones", () => {
    for (const selector of [".card-detail__stage", ".public-card__stage", ".hub-showcase__stage"]) {
      expect(ruleBody(cardRarityEffectsStylesheet, selector)).toContain("overflow-x: clip")
    }
    for (const selector of [".card-detail__stage", ".public-card__stage"]) {
      expect(ruleBody(cardDetailStylesheet, selector)).toContain("min-width: min(340px, 100%)")
    }
    expect(ruleBody(cardRarityEffectsStylesheet, ".card-detail__stage .card-rays")).toContain(
      "mask-image: radial-gradient(circle 170px, #000 40%, transparent 100%)",
    )
    expect(cardRarityEffectsStylesheet).toContain(".public-card__stage .card-rays")
    expect(ruleBody(hubStylesheet, ".hub-showcase__stage")).toContain("align-self: stretch")
    expect(cardDetailStylesheet).toContain("@container (min-width: 520px)")
    expect(ruleBody(cardDetailStylesheet, ".card-detail")).toContain("max-width: var(--space-breakpoint-two-columns)")
    expect(ruleBody(cardDetailStylesheet, ".card-detail__nav")).toContain("z-index: 1")
  })

  it("stops every loop under reduced motion but keeps card rays visible", () => {
    for (const prefix of ['html[data-motion="reduced"]', 'html:not([data-motion="full"])']) {
      expect(rule(cardRarityEffectsStylesheet, `${prefix} .card-rays`)).toContain("animation: none")
      expect(rule(cardRarityEffectsStylesheet, `${prefix} .card-float`)).toContain("animation: none")
    }
    const reducedAt = boosterLayoutsStylesheet.lastIndexOf('html[data-motion="reduced"] .booster-card__rays')
    expect(reducedAt).toBeGreaterThan(-1)
    const reducedHide = boosterLayoutsStylesheet.slice(reducedAt)
    expect(reducedHide.slice(0, reducedHide.indexOf("}"))).toContain("display: none")
  })
})
