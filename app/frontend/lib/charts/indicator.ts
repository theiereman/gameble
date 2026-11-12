import type { ChartConfiguration, Plugin, TooltipItem } from "chart.js"
import { t } from "../i18n"
import { animation, categoryAxis, dayTitle, labelFont, LINE_WIDTH, picoinAxis, tooltipFrame } from "./base"
import { compactTick, indexValue } from "./format"
import type { ChartData, DrawOptions, Point } from "./types"

export const THRESHOLD_DASH = [6, 4]
export const THRESHOLD_LABEL_SIZE = 10
export const THRESHOLD_LABEL_OFFSET = 6

type Unit = "share" | "days" | "picoins"

type Format = (value: number, options: DrawOptions) => string

const FORMATS: Readonly<Record<Unit, Format>> = {
  share: (value, options) => unitValue(indexValue(value, options.locale), options),
  days: (value, options) => unitValue(indexValue(value, options.locale), options),
  picoins: (value, options) => compactTick(value, options.locale),
}

function unitValue(value: string, options: DrawOptions): string {
  return options.words.tick ? t(options.words.tick, { value }) : value
}

function lastPoint(values: readonly Point[]): { index: number; value: number } | null {
  for (let index = values.length - 1; index >= 0; index -= 1) {
    const value = values[index]
    if (value !== null && value !== undefined) return { index, value }
  }
  return null
}

export function thresholdLabel(data: ChartData, options: DrawOptions): Plugin<"line"> {
  return {
    id: "thresholdLabel",
    afterDatasetsDraw(chart) {
      const point = lastPoint(data.series.threshold ?? [])
      const datasetIndex = chart.data.datasets.findIndex((dataset) => dataset.label === options.words.series?.threshold)
      const element = point && datasetIndex >= 0 ? chart.getDatasetMeta(datasetIndex).data[point.index] : undefined
      if (!element || !options.words.threshold) return
      const { ctx } = chart
      ctx.save()
      ctx.font = `bold ${THRESHOLD_LABEL_SIZE}px ${options.theme.fontFamily}`
      ctx.fillStyle = options.theme.series.threshold ?? options.theme.text
      ctx.textAlign = "right"
      ctx.textBaseline = "bottom"
      ctx.fillText(options.words.threshold, element.x, element.y - THRESHOLD_LABEL_OFFSET)
      ctx.restore()
    },
  }
}

function indicatorConfiguration(unit: Unit) {
  return (data: ChartData, options: DrawOptions): ChartConfiguration<"line", Point[], string> => {
    const format = FORMATS[unit]
    const words = options.words.series ?? {}
    const datasets: ChartConfiguration<"line", Point[], string>["data"]["datasets"] = [
      {
        label: words.value ?? "value",
        data: data.series.value ?? [],
        borderColor: options.theme.series.value,
        backgroundColor: options.theme.series.value,
        borderWidth: LINE_WIDTH,
        pointRadius: 0,
        pointHitRadius: 8,
        spanGaps: false,
      },
    ]
    if (data.series.threshold) {
      datasets.push({
        label: words.threshold ?? "threshold",
        data: data.series.threshold,
        borderColor: options.theme.series.threshold,
        borderWidth: LINE_WIDTH,
        borderDash: THRESHOLD_DASH,
        pointRadius: 0,
        pointHitRadius: 0,
        spanGaps: false,
      })
    }
    const yAxis =
      unit === "picoins"
        ? picoinAxis(options)
        : {
            ...picoinAxis(options),
            ticks: {
              ...picoinAxis(options).ticks,
              callback: (value: number | string) => format(Number(value), options),
            },
          }
    return {
      type: "line",
      data: { labels: data.labels, datasets },
      options: {
        animation: animation(options),
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        scales: { x: categoryAxis(options), y: yAxis },
        plugins: {
          tooltip: {
            ...tooltipFrame(options),
            callbacks: {
              title: dayTitle(data.labels),
              label: (item: TooltipItem<"line">) => {
                const value = item.parsed.y
                if (value === null || value === undefined || !options.words.tooltip) return ""
                return t(options.words.tooltip, { series: item.dataset.label ?? "", value: format(value, options) })
              },
            },
          },
        },
      },
      plugins: [thresholdLabel(data, options)],
    }
  }
}

export const shareIndicatorConfiguration = indicatorConfiguration("share")
export const daysIndicatorConfiguration = indicatorConfiguration("days")
export const picoinsIndicatorConfiguration = indicatorConfiguration("picoins")
