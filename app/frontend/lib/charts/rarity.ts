import type { ChartConfiguration, Plugin, PointStyle, TooltipItem } from "chart.js"
import { t } from "../i18n"
import { animation, categoryAxis, dayTitle, labelFont, lastPoint, LINE_WIDTH, tooltipFrame } from "./base"
import { indexValue } from "./format"
import type { ChartData, DrawOptions, Point } from "./types"

export const RARITY_KEYS = ["common", "uncommon", "rare", "epic", "legendary"] as const

type RarityKey = (typeof RARITY_KEYS)[number]

type RarityShape = { style: PointStyle; hollow: boolean }

export const RARITY_SHAPES: Readonly<Record<RarityKey, RarityShape>> = {
  common: { style: "circle", hollow: false },
  uncommon: { style: "circle", hollow: true },
  rare: { style: "rectRot", hollow: false },
  epic: { style: "triangle", hollow: false },
  legendary: { style: "star", hollow: false },
}

export const MARKER_EVERY = 15
export const MARKER_RADIUS = 4
export const END_LABEL_SPACE = 128
export const END_LABEL_GAP = 13

export function markerRadii(values: readonly Point[]): number[] {
  let last = -1
  values.forEach((value, index) => {
    if (value !== null) last = index
  })
  return values.map((value, index) =>
    value !== null && (index % MARKER_EVERY === 0 || index === last) ? MARKER_RADIUS : 0,
  )
}

function rarityKeys(data: ChartData): RarityKey[] {
  return RARITY_KEYS.filter((key) => key in data.series)
}

export type EndLabel = { text: string; color: string; x: number; y: number }

export function spreadLabels(labels: readonly EndLabel[], gap: number = END_LABEL_GAP): EndLabel[] {
  const sorted = [...labels].sort((first, second) => first.y - second.y)
  let floor = -Infinity
  return sorted.map((label) => {
    const y = Math.max(label.y, floor + gap)
    floor = y
    return { ...label, y }
  })
}

export function endLabels(data: ChartData, options: DrawOptions): Plugin<"line"> {
  return {
    id: "rarityEndLabels",
    afterDatasetsDraw(chart) {
      if (options.narrow) return
      const labels: EndLabel[] = []
      chart.data.datasets.forEach((dataset, datasetIndex) => {
        const key = rarityKeys(data)[datasetIndex]
        const point = key ? lastPoint(data.series[key] ?? []) : null
        const element = point ? chart.getDatasetMeta(datasetIndex).data[point.index] : undefined
        if (!key || !point || !element) return
        labels.push({
          text: `${dataset.label ?? key} ${indexValue(point.value, options.locale)}`,
          color: options.theme.series[key] ?? options.theme.text,
          x: element.x + 8,
          y: element.y,
        })
      })
      const { ctx } = chart
      ctx.save()
      ctx.font = `bold ${labelFont(options).size}px ${options.theme.fontFamily}`
      ctx.textBaseline = "middle"
      for (const label of spreadLabels(labels)) {
        ctx.fillStyle = label.color
        ctx.fillText(label.text, label.x, label.y)
      }
      ctx.restore()
    },
  }
}

export function rarityIndexConfiguration(
  data: ChartData,
  options: DrawOptions,
): ChartConfiguration<"line", Point[], string> {
  return {
    type: "line",
    data: {
      labels: data.labels,
      datasets: rarityKeys(data).map((key) => {
        const values = data.series[key] ?? []
        const color = options.theme.series[key]
        const shape = RARITY_SHAPES[key]
        return {
          label: options.words.series?.[key] ?? key,
          data: values,
          borderColor: color,
          backgroundColor: color,
          borderWidth: LINE_WIDTH,
          pointStyle: shape.style,
          pointRadius: markerRadii(values),
          pointHoverRadius: MARKER_RADIUS + 1,
          pointBackgroundColor: shape.hollow ? options.theme.panel : color,
          pointBorderColor: color,
          pointBorderWidth: shape.hollow ? LINE_WIDTH : 1,
          pointHitRadius: 8,
          spanGaps: false,
        }
      }),
    },
    options: {
      animation: animation(options),
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      layout: { padding: { right: options.narrow ? 0 : END_LABEL_SPACE } },
      scales: {
        x: categoryAxis(options),
        y: {
          type: "linear",
          grid: { color: options.theme.grid, lineWidth: 1 },
          border: { display: false },
          ticks: {
            color: options.theme.axisText,
            font: labelFont(options),
            maxTicksLimit: 5,
            callback: (value: number | string) => indexValue(Number(value), options.locale),
          },
        },
      },
      plugins: {
        tooltip: {
          ...tooltipFrame(options),
          callbacks: {
            title: dayTitle(data.labels),
            label: (item: TooltipItem<"line">) => {
              const key = rarityKeys(data)[item.datasetIndex]
              const value = key ? data.series[key]?.[item.dataIndex] : null
              if (!key || value === null || value === undefined || !options.words.tooltip) return ""
              const series = options.words.series?.[key] ?? key
              return t(options.words.tooltip, { series, value: indexValue(value, options.locale) })
            },
          },
        },
      },
    },
    plugins: [endLabels(data, options)],
  }
}

export function sparklineConfiguration(
  data: ChartData,
  options: DrawOptions,
): ChartConfiguration<"line", Point[], string> {
  const key = Object.keys(data.series)[0] ?? ""
  return {
    type: "line",
    data: {
      labels: data.labels,
      datasets: [
        {
          data: data.series[key] ?? [],
          borderColor: options.theme.series[key],
          borderWidth: LINE_WIDTH,
          pointRadius: 0,
          spanGaps: false,
        },
      ],
    },
    options: {
      animation: false,
      responsive: true,
      maintainAspectRatio: false,
      events: [],
      scales: { x: { type: "category", display: false }, y: { type: "linear", display: false } },
      plugins: { tooltip: { enabled: false } },
    },
  }
}
