import type { TooltipItem } from "chart.js"
import { describe, expect, it } from "vitest"
import { belowAxis, circulationConfiguration, reactorConfiguration } from "./reactor"
import type { ChartData, DrawOptions } from "./types"

const data: ChartData = {
  kind: "reactor",
  labels: ["Nov 8", "Nov 9", "Nov 10"],
  series: { minted: [12_000, null, 9_000], destroyed: [5_000, null, 11_000], balance: [7_000, null, -2_000] },
}

const options = (overrides: Partial<DrawOptions> = {}): DrawOptions => ({
  theme: {
    series: { minted: "#f4c542", destroyed: "#66c0f4", circulation: "#fff" },
    text: "#c7d5e0",
    axisText: "#8f98a0",
    grid: "#1f3346",
    tooltipBackground: "#1b2838",
    tooltipBorder: "#2a475e",
    panel: "#16202d",
    fontFamily: "JetBrains Mono",
  },
  words: {
    series: { minted: "Minted", destroyed: "Destroyed", circulation: "In circulation" },
    tooltip: "%{series}: %{value}",
    balance: "Day's balance: %{amount}",
  },
  locale: "en",
  reducedMotion: false,
  ...overrides,
})

const item = (datasetIndex: number, dataIndex: number) => ({ datasetIndex, dataIndex }) as TooltipItem<"bar">

describe("reactor configuration", () => {
  it("draws minted above the axis and destroyed below it, keeping the gaps", () => {
    const [minted, destroyed] = reactorConfiguration(data, options()).data.datasets

    expect(minted.data).toEqual([12_000, null, 9_000])
    expect(destroyed.data).toEqual([-5_000, null, -11_000])
    expect(belowAxis([0, null])).toEqual([-0, null])
  })

  it("colours each series from its resolved token, with rounded ends away from the axis", () => {
    const [minted, destroyed] = reactorConfiguration(data, options()).data.datasets

    expect(minted.backgroundColor).toBe("#f4c542")
    expect(destroyed.backgroundColor).toBe("#66c0f4")
    expect(minted.borderRadius).toBe(4)
    expect(minted.borderSkipped).toBe("start")
  })

  it("has one stacked y-axis on a category x-axis", () => {
    const scales = reactorConfiguration(data, options()).options?.scales ?? {}

    expect(Object.keys(scales)).toEqual(["x", "y"])
    expect(scales.x?.type).toBe("category")
    expect(scales.y?.type).toBe("linear")
  })

  it("draws without animation when motion is reduced", () => {
    expect(reactorConfiguration(data, options({ reducedMotion: true })).options?.animation).toBe(false)
    expect(reactorConfiguration(data, options()).options?.animation).toEqual({ duration: 400 })
  })

  it("names the day, each series' server value and the day's balance from the server", () => {
    const callbacks = reactorConfiguration(data, options()).options?.plugins?.tooltip?.callbacks
    const title = callbacks?.title as unknown as (items: TooltipItem<"bar">[]) => string
    const label = callbacks?.label as unknown as (item: TooltipItem<"bar">) => string
    const footer = callbacks?.footer as unknown as (items: TooltipItem<"bar">[]) => string

    expect(title([item(0, 2)])).toBe("Nov 10")
    expect(label(item(0, 2))).toBe("Minted: 9,000")
    expect(label(item(1, 2))).toBe("Destroyed: 11,000")
    expect(footer([item(0, 2)])).toBe("Day's balance: −2,000")
    expect(footer([item(0, 0)])).toBe("Day's balance: +7,000")
    expect(label(item(0, 1))).toBe("")
    expect(footer([item(0, 1)])).toBe("")
  })

  it("labels the axis with compact figures, signed below the axis", () => {
    const callback = reactorConfiguration(data, options({ locale: "fr" })).options?.scales?.y?.ticks
      ?.callback as unknown as (value: number) => string

    expect(callback(31_599)).toBe("31,5k")
    expect(callback(-12_000)).toBe("−12k")
    expect(callback(0)).toBe("0")
  })
})

describe("circulation configuration", () => {
  const circulation: ChartData = {
    kind: "circulation",
    labels: data.labels,
    series: { circulation: [400_000, null, 412_600] },
  }

  it("draws one white line with its gaps on one y-axis", () => {
    const configuration = circulationConfiguration(circulation, options())
    const [line] = configuration.data.datasets

    expect(configuration.type).toBe("line")
    expect(line.data).toEqual([400_000, null, 412_600])
    expect(line.borderColor).toBe("#fff")
    expect(line.spanGaps).toBe(false)
    expect(Object.keys(configuration.options?.scales ?? {})).toEqual(["x", "y"])
  })

  it("places each day on the same band and plot width as the Reactor's bars", () => {
    const line = circulationConfiguration(circulation, options()).options?.scales
    const bars = reactorConfiguration(data, options()).options?.scales
    const lineWidth = { width: 0 }
    const barWidth = { width: 0 }
    const fit = (axis: unknown, measured: { width: number }) =>
      (axis as { afterFit: (scale: { width: number }) => void }).afterFit(measured)

    expect(line?.x).toMatchObject({ offset: true })
    expect(bars?.x).toMatchObject({ offset: true })
    fit(line?.y, lineWidth)
    fit(bars?.y, barWidth)
    expect(lineWidth.width).toBeGreaterThan(0)
    expect(lineWidth.width).toBe(barWidth.width)
  })

  it("draws without animation when motion is reduced", () => {
    expect(circulationConfiguration(circulation, options({ reducedMotion: true })).options?.animation).toBe(false)
  })
})
