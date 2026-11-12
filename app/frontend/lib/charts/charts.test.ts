import { describe, expect, it } from "vitest"
import { configurationFor, seriesKeys } from "./configurations"
import { compactTick, signedPicoins } from "./format"
import { picoins } from "../picoins"
import { resolveTheme } from "./theme"
import type { ChartData, DrawOptions } from "./types"

const tokens: Record<string, string> = {
  "--color-chart-minted": " #f4c542",
  "--color-chart-destroyed": "#66c0f4 ",
  "--color-text-max": "#fff",
  "--color-text": "#c7d5e0",
  "--color-muted": "#8f98a0",
  "--color-line-soft": "#1f3346",
  "--color-panel-raised": "#1b2838",
  "--color-line": "#2a475e",
  "--font-family-jetbrains-mono": '"JetBrains Mono", monospace',
}

describe("theme", () => {
  it("resolves each series key to its chart token and the chrome to the text and line tokens", () => {
    const theme = resolveTheme((name) => tokens[name] ?? "", ["minted", "destroyed", "balance"])

    expect(theme.series).toEqual({ minted: "#f4c542", destroyed: "#66c0f4" })
    expect(theme.axisText).toBe("#8f98a0")
    expect(theme.grid).toBe("#1f3346")
    expect(theme.fontFamily).toBe('"JetBrains Mono", monospace')
  })
})

describe("signed and compact figures", () => {
  it("signs a balance with plus or the minus sign", () => {
    expect(signedPicoins(1_234, "fr")).toBe(`+${picoins(1_234, { locale: "fr" })}`)
    expect(signedPicoins(-1_234, "en")).toBe("−1,234")
    expect(signedPicoins(0, "en")).toBe("0")
  })

  it("draws axis figures in the compact form, signed below zero", () => {
    expect(compactTick(412_600_000, "fr")).toBe("412,6M")
    expect(compactTick(-2_500, "en")).toBe("−2.5k")
    expect(compactTick(-0, "en")).toBe("0")
  })
})

describe("configurations", () => {
  const options: DrawOptions = {
    theme: resolveTheme((name) => tokens[name] ?? "", ["minted", "destroyed"]),
    words: {},
    locale: "en",
    reducedMotion: true,
  }

  it("builds a configuration for each known kind and none for an unknown one", () => {
    const reactor: ChartData = { kind: "reactor", labels: ["a"], series: { minted: [1], destroyed: [1] } }

    expect(configurationFor(reactor, options)?.type).toBe("bar")
    expect(configurationFor({ ...reactor, kind: "circulation" }, options)?.type).toBe("line")
    expect(configurationFor({ ...reactor, kind: "unknown" }, options)).toBeNull()
    expect(seriesKeys(reactor)).toEqual(["minted", "destroyed"])
  })
})

const sources: Record<string, string> = import.meta.glob(["../../**/*.ts", "!../../**/*.test.ts", "!../../images/**"], {
  query: "?raw",
  import: "default",
  eager: true,
})

describe("loading Chart.js", () => {
  it("is imported at run time by the registration module alone, never through chart.js/auto", () => {
    const importers = Object.entries(sources)
      .filter(([, source]) => /^import (?!type\b)(?:(?!\bfrom\b)[\s\S])*\bfrom "chart\.js/m.test(source))
      .map(([path]) => path)

    expect(importers).toEqual(["./registration.ts"])
    expect(Object.values(sources).some((source) => source.includes("chart.js/auto"))).toBe(false)
  })

  it("is reached by one dynamic import from the chart controller", () => {
    const loaders = Object.entries(sources)
      .filter(([, source]) => source.includes('import("../lib/charts/registration")'))
      .map(([path]) => path)

    expect(loaders).toEqual(["../../controllers/chart_controller.ts"])
  })
})
