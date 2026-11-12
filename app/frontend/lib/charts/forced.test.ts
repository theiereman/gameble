import { describe, expect, it } from "vitest"
import { configurationFor } from "./configurations"
import { FORCED_DASHES, FORCED_MUTED, FORCED_TEXT, forcedTheme } from "./forced"
import { RARITY_KEYS } from "./rarity"
import type { ChartData, DrawOptions } from "./types"

const labels = ["Nov 8", "Nov 9"]

const options = (keys: string[], overrides: Partial<DrawOptions> = {}): DrawOptions => ({
  theme: forcedTheme(keys, "JetBrains Mono"),
  words: { series: {}, tooltip: "%{series}: %{value}" },
  locale: "en",
  reducedMotion: false,
  forcedColors: true,
  ...overrides,
})

const index: ChartData = {
  kind: "rarity_index",
  labels,
  series: Object.fromEntries(RARITY_KEYS.map((key, rank) => [key, [100, 100 + rank]])),
}

const reactor: ChartData = {
  kind: "reactor",
  labels,
  series: { minted: [10, 12], destroyed: [5, 6], balance: [5, 6] },
}

describe("forced colours", () => {
  it("draws every series in the system text colour on the system background", () => {
    const theme = forcedTheme(["minted", "epic"], "JetBrains Mono")

    expect(theme.series).toEqual({ minted: FORCED_TEXT, epic: FORCED_TEXT })
    expect(theme.grid).toBe(FORCED_MUTED)
    expect(theme.tooltipBackground).toBe("Canvas")
  })

  it("tells line series apart by dash and shape, keeping a series' own dash and shape", () => {
    const datasets = configurationFor(index, options([...RARITY_KEYS]))?.data.datasets ?? []

    expect(datasets.map((dataset) => (dataset as { borderDash?: number[] }).borderDash)).toEqual(FORCED_DASHES)
    const markers = datasets.map((dataset) => {
      const marker = dataset as { pointStyle?: string; pointBackgroundColor?: string }
      return `${marker.pointStyle}:${marker.pointBackgroundColor}`
    })
    expect(new Set(markers).size).toBe(5)
    expect(datasets.every((dataset) => dataset.borderColor === FORCED_TEXT)).toBe(true)
  })

  it("fills the minted and destroyed bars apart, and leaves the colours alone outside forced colours", () => {
    const forced = configurationFor(reactor, options(["minted", "destroyed"]))?.data.datasets ?? []
    expect(forced.map((dataset) => dataset.backgroundColor)).toEqual([FORCED_TEXT, FORCED_MUTED])

    const plain = configurationFor(
      reactor,
      options(["minted", "destroyed"], {
        forcedColors: false,
        theme: { ...forcedTheme([], ""), series: { minted: "#f4c542", destroyed: "#66c0f4" } },
      }),
    )?.data.datasets
    expect(plain?.map((dataset) => dataset.backgroundColor)).toEqual(["#f4c542", "#66c0f4"])
  })
})

describe("phone layout and taps", () => {
  it("drops the end labels and their room under 720 CSS px, where the HTML legend names each rarity", () => {
    const wide = configurationFor(index, options([...RARITY_KEYS], { forcedColors: false }))
    const narrow = configurationFor(index, options([...RARITY_KEYS], { forcedColors: false, narrow: true }))

    expect(wide?.options?.layout?.padding).toMatchObject({ right: expect.any(Number) })
    expect(narrow?.options?.layout?.padding).toEqual({ right: 0 })
  })

  it("picks the nearest point on a tap, without having to hit it, for every kind", () => {
    const kinds: ChartData[] = [
      reactor,
      { kind: "circulation", labels, series: { circulation: [1, 2] } },
      index,
      { kind: "edition_sales", labels, x: [1, 2], series: { epic: [1, 2], floor: [1, 1] } },
      { kind: "indicator_share", labels, series: { value: [1, 2] } },
    ]

    for (const data of kinds) {
      const interaction = configurationFor(data, options(seriesOf(data)))?.options?.interaction
      expect(interaction?.intersect, data.kind).toBe(false)
    }
  })
})

function seriesOf(data: ChartData): string[] {
  return Object.keys(data.series)
}
