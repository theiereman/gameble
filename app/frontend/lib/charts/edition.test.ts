import { describe, expect, it } from "vitest"
import { configurationFor } from "./configurations"
import { dayTick, editionConfiguration, FLOOR_DASH, points, SALE_RING } from "./edition"
import { resolveTheme } from "./theme"
import type { ChartData, DrawOptions } from "./types"

const tokens: Record<string, string> = {
  "--color-rarity-epique": "#b47cff",
  "--color-rarity-peu-commune": "#3fcf8e",
  "--color-text-max": "#fff",
  "--color-chart-floor": "#8f98a0",
  "--color-panel": "#16202d",
}

const options = (keys: string[]): DrawOptions => ({
  theme: resolveTheme((name) => tokens[name] ?? "", keys),
  words: {
    series: { epic: "A sale", uncommon: "A sale", average: "Average price", floor: "Epic floor · 1,300" },
    tooltip: "%{series}: %{value}",
  },
  locale: "en",
  reducedMotion: false,
})

const NOV_8 = Date.UTC(2026, 10, 8, 14)
const NOV_9 = Date.UTC(2026, 10, 9, 9)
const NOV_10 = Date.UTC(2026, 10, 10, 20)

const priced: ChartData = {
  kind: "edition_sales",
  labels: ["Nov 8", "Nov 9", "Nov 10"],
  x: [NOV_8, NOV_9, NOV_10],
  series: { epic: [2_400, 2_200, 3_000], average: [2_400, 2_300, 2_400], floor: [1_300, 1_300, 1_300] },
}

describe("edition configuration", () => {
  it("places each sale on a linear axis in epoch milliseconds, in the rarity's colour and shape with a panel ring", () => {
    const configuration = editionConfiguration(priced, options(["epic", "average", "floor"]))
    const [sales] = configuration.data.datasets

    expect(configuration.type).toBe("scatter")
    expect(configuration.options?.scales?.x?.type).toBe("linear")
    expect(sales?.data).toEqual([
      { x: NOV_8, y: 2_400 },
      { x: NOV_9, y: 2_200 },
      { x: NOV_10, y: 3_000 },
    ])
    expect(sales?.pointStyle).toBe("triangle")
    expect(sales?.backgroundColor).toBe("#b47cff")
    expect(sales?.borderColor).toBe("#16202d")
    expect(sales?.borderWidth).toBe(SALE_RING)
  })

  it("steps the average after each sale and dashes the flat floor", () => {
    const [, average, floor] = editionConfiguration(priced, options(["epic", "average", "floor"])).data.datasets

    expect(average?.label).toBe("Average price")
    expect(average?.stepped).toBe("after")
    expect(average?.borderColor).toBe("#fff")
    expect(floor?.borderDash).toEqual(FLOOR_DASH)
    expect(floor?.data.map((point) => point.y)).toEqual([1_300, 1_300, 1_300])
  })

  it("draws no average under the minimum sale count", () => {
    const few: ChartData = { ...priced, series: { uncommon: [2_400, 2_200], floor: [1_300, 1_300] }, x: [NOV_8, NOV_9] }
    const datasets = configurationFor(few, options(["uncommon", "floor"]))?.data.datasets ?? []

    expect(datasets.map((dataset) => dataset.label)).toEqual(["A sale", "Epic floor · 1,300"])
    expect(datasets[0]?.backgroundColor).toBe("#16202d")
  })

  it("skips a missing value and labels the axis by day in UTC", () => {
    expect(points([NOV_8, NOV_9], [null, 5])).toEqual([{ x: NOV_9, y: 5 }])
    expect(dayTick("en")(NOV_10)).toBe("Nov 10")
  })
})
