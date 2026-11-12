import type { PointStyle } from "chart.js"
import type { ChartTheme, DrawnConfiguration } from "./types"

export const FORCED_DASHES: ReadonlyArray<number[]> = [[], [6, 3], [2, 3], [10, 3, 2, 3], [1, 4]]
export const FORCED_SHAPES: ReadonlyArray<PointStyle> = ["circle", "rect", "triangle", "rectRot", "star"]
export const FORCED_TEXT = "CanvasText"
export const FORCED_BACKGROUND = "Canvas"
export const FORCED_MUTED = "GrayText"

export function forcedTheme(keys: readonly string[], fontFamily: string): ChartTheme {
  return {
    series: Object.fromEntries(keys.map((key) => [key, FORCED_TEXT])),
    text: FORCED_TEXT,
    axisText: FORCED_TEXT,
    grid: FORCED_MUTED,
    tooltipBackground: FORCED_BACKGROUND,
    tooltipBorder: FORCED_TEXT,
    panel: FORCED_BACKGROUND,
    fontFamily,
  }
}

type Distinguishable = {
  type?: string
  borderDash?: number[]
  pointStyle?: unknown
  backgroundColor?: unknown
}

export function distinguishSeries(configuration: DrawnConfiguration): DrawnConfiguration {
  configuration.data.datasets.forEach((dataset, index) => {
    const series = dataset as Distinguishable
    if (configuration.type === "bar") {
      series.backgroundColor = index === 0 ? FORCED_TEXT : FORCED_MUTED
      return
    }
    series.borderDash = series.borderDash ?? FORCED_DASHES[index % FORCED_DASHES.length]
    series.pointStyle = series.pointStyle ?? FORCED_SHAPES[index % FORCED_SHAPES.length]
  })
  return configuration
}
