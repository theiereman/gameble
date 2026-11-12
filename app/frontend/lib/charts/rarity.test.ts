import { describe, expect, it } from "vitest"
import { configurationFor } from "./configurations"
import { indexValue } from "./format"
import { markerRadii, MARKER_RADIUS, RARITY_KEYS, RARITY_SHAPES, rarityIndexConfiguration } from "./rarity"
import { resolveTheme } from "./theme"
import type { ChartData, DrawOptions } from "./types"

const days = (count: number) => Array.from({ length: count }, (_, index) => `Day ${index + 1}`)

const rarityTokens: Record<string, string> = {
  "--color-rarity-commune": "#8f98a0",
  "--color-rarity-peu-commune": "#3fcf8e",
  "--color-rarity-rare": "#66c0f4",
  "--color-rarity-epique": "#b47cff",
  "--color-rarity-legendaire": "#f4c542",
  "--color-panel": "#16202d",
}

const options = (overrides: Partial<DrawOptions> = {}): DrawOptions => ({
  theme: resolveTheme((name) => rarityTokens[name] ?? "", [...RARITY_KEYS]),
  words: {
    series: { common: "Common", uncommon: "Uncommon", rare: "Rare", epic: "Epic", legendary: "Legendary" },
    tooltip: "%{series}: %{value}",
  },
  locale: "en",
  reducedMotion: false,
  ...overrides,
})

const flat = (value: number | null) => Array.from({ length: 90 }, () => value)

const index: ChartData = {
  kind: "rarity_index",
  labels: days(90),
  series: {
    common: flat(100),
    uncommon: flat(null),
    rare: flat(104.5),
    epic: [...flat(120).slice(1), 143],
    legendary: flat(98),
  },
}

describe("rarity index configuration", () => {
  it("draws every rarity in its colour and shape, the uncommon ring hollow, on one y-axis", () => {
    const configuration = rarityIndexConfiguration(index, options())
    const datasets = configuration.data.datasets

    expect(datasets.map((dataset) => dataset.label)).toEqual(["Common", "Uncommon", "Rare", "Epic", "Legendary"])
    expect(datasets.map((dataset) => dataset.pointStyle)).toEqual(["circle", "circle", "rectRot", "triangle", "star"])
    expect(datasets[3]?.borderColor).toBe("#b47cff")
    expect(datasets[1]?.pointBackgroundColor).toBe("#16202d")
    expect(datasets[0]?.pointBackgroundColor).toBe("#8f98a0")
    expect(Object.keys(configuration.options?.scales ?? {})).toEqual(["x", "y"])
    expect(configuration.plugins?.map((plugin) => plugin.id)).toEqual(["rarityEndLabels"])
  })

  it("tells each rarity apart by a distinct shape", () => {
    const shapes = RARITY_KEYS.map((key) => `${RARITY_SHAPES[key].style}:${RARITY_SHAPES[key].hollow}`)

    expect(new Set(shapes).size).toBe(RARITY_KEYS.length)
  })

  it("marks a point every 15 days and on the last point, never on a gap", () => {
    const values = [...flat(110).slice(0, 40), null, null]
    const radii = markerRadii(values)

    expect(radii.filter((radius) => radius > 0).length).toBe(4)
    expect([radii[0], radii[15], radii[30], radii[39]]).toEqual(Array(4).fill(MARKER_RADIUS))
    expect([radii[1], radii[40], radii[41]]).toEqual([0, 0, 0])
  })

  it("names the rarity and its index in the tooltip, and draws at once when motion is reduced", () => {
    const configuration = rarityIndexConfiguration(index, options({ reducedMotion: true }))
    const label = configuration.options?.plugins?.tooltip?.callbacks?.label as unknown as (item: {
      datasetIndex: number
      dataIndex: number
    }) => string

    expect(label({ datasetIndex: 3, dataIndex: 89 })).toBe("Epic: 143")
    expect(label({ datasetIndex: 1, dataIndex: 89 })).toBe("")
    expect(configuration.options?.animation).toBe(false)
  })

  it("prints index values with at most one decimal in the reader's locale", () => {
    expect(indexValue(104.5, "fr")).toBe("104,5")
    expect(indexValue(143, "en")).toBe("143")
    expect(indexValue(99.96, "en")).toBe("100")
    expect(indexValue(-2.5, "fr")).toBe("−2,5")
  })
})

describe("sparkline configuration", () => {
  it("draws one quiet line, without axes, points, tooltip or animation", () => {
    const sparkline: ChartData = { kind: "sparkline", labels: days(3), series: { epic: [1.2, null, 1.6] } }
    const configuration = configurationFor(sparkline, options())

    expect(configuration?.type).toBe("line")
    const [line] = configuration?.data.datasets ?? []
    expect(line?.data).toEqual([1.2, null, 1.6])
    expect(line?.borderColor).toBe("#b47cff")
    expect(configuration?.options?.animation).toBe(false)
    expect(configuration?.options?.events).toEqual([])
    expect(configuration?.options?.plugins?.tooltip?.enabled).toBe(false)
  })
})
