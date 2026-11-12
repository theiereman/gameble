import { describe, expect, it } from "vitest"
import { configurationFor } from "./configurations"
import { shareIndicatorConfiguration, THRESHOLD_DASH } from "./indicator"
import { resolveTheme } from "./theme"
import type { ChartData, DrawOptions } from "./types"

const tokens: Record<string, string> = { "--color-text-max": "#fff", "--color-chart-threshold": "#e8833a" }

const options = (overrides: Partial<DrawOptions["words"]> = {}): DrawOptions => ({
  theme: resolveTheme((name) => tokens[name] ?? "", ["value", "threshold"]),
  words: {
    series: { value: "Destroyed / minted", threshold: "Alert threshold" },
    tick: "%{value}%",
    tooltip: "%{series}: %{value}",
    threshold: "ALERT 40%",
    ...overrides,
  },
  locale: "en",
  reducedMotion: false,
})

const share: ChartData = {
  kind: "indicator_share",
  labels: ["Nov 8", "Nov 9", "Nov 10"],
  series: { value: [55.9, null, 38.5], threshold: [40, 40, 40] },
}

const tick = (configuration: ReturnType<typeof configurationFor>, value: number) =>
  (configuration?.options?.scales?.y?.ticks as { callback: (value: number) => string }).callback(value)

describe("indicator configurations", () => {
  it("draws the indicator as a line with its gaps and its threshold as a dashed flat series on one y-axis", () => {
    const configuration = shareIndicatorConfiguration(share, options())
    const [line, threshold] = configuration.data.datasets

    expect(configuration.type).toBe("line")
    expect(line?.data).toEqual([55.9, null, 38.5])
    expect(line?.borderColor).toBe("#fff")
    expect(threshold?.borderDash).toEqual(THRESHOLD_DASH)
    expect(threshold?.borderColor).toBe("#e8833a")
    expect(Object.keys(configuration.options?.scales ?? {})).toEqual(["x", "y"])
    expect(configuration.plugins?.map((plugin) => plugin.id)).toEqual(["thresholdLabel"])
  })

  it("has no threshold series where the indicator has none", () => {
    const configuration = configurationFor({ ...share, series: { value: [1, 2, 3] } }, options())

    expect(configuration?.data.datasets).toHaveLength(1)
  })

  it("labels the axis in the indicator's unit", () => {
    expect(tick(configurationFor(share, options()), 55.9)).toBe("55.9%")
    expect(tick(configurationFor({ ...share, kind: "indicator_days" }, options({ tick: "%{value} d" })), 1.5)).toBe(
      "1.5 d",
    )
    expect(tick(configurationFor({ ...share, kind: "indicator_picoins" }, options()), 31_500)).toBe("31.5k")
  })
})
