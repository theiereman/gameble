import type { ChartConfiguration, TooltipItem } from "chart.js"
import { t } from "../i18n"
import { picoins } from "../picoins"
import { animation, BAR_END_RADIUS, categoryAxis, dayTitle, LINE_WIDTH, picoinAxis, tooltipFrame } from "./base"
import { signedPicoins } from "./format"
import type { ChartData, DrawOptions, Point } from "./types"

export const FLOW_KEYS = ["minted", "destroyed"] as const

type FlowKey = (typeof FLOW_KEYS)[number]

export function belowAxis(values: readonly Point[]): Point[] {
  return values.map((value) => (value === null ? null : -value))
}

function seriesOf(data: ChartData, key: string): Point[] {
  return data.series[key] ?? data.labels.map(() => null)
}

function valueLine(data: ChartData, options: DrawOptions, key: string, index: number): string | null {
  const value = seriesOf(data, key)[index]
  if (value === null || value === undefined || !options.words.tooltip) return null
  const series = options.words.series?.[key] ?? key
  return t(options.words.tooltip, { series, value: picoins(value, { locale: options.locale }) })
}

export function reactorConfiguration(
  data: ChartData,
  options: DrawOptions,
): ChartConfiguration<"bar", Point[], string> {
  const drawn: Record<FlowKey, Point[]> = {
    minted: seriesOf(data, "minted"),
    destroyed: belowAxis(seriesOf(data, "destroyed")),
  }
  return {
    type: "bar",
    data: {
      labels: data.labels,
      datasets: FLOW_KEYS.map((key) => ({
        label: options.words.series?.[key] ?? key,
        data: drawn[key],
        backgroundColor: options.theme.series[key],
        borderRadius: BAR_END_RADIUS,
        borderSkipped: "start" as const,
        stack: "flows",
      })),
    },
    options: {
      animation: animation(options),
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      scales: {
        x: { ...categoryAxis(options), stacked: true },
        y: { ...picoinAxis(options), stacked: true },
      },
      plugins: {
        tooltip: {
          ...tooltipFrame(options),
          callbacks: {
            title: dayTitle(data.labels),
            label: (item: TooltipItem<"bar">) =>
              valueLine(data, options, FLOW_KEYS[item.datasetIndex], item.dataIndex) ?? "",
            footer: (items: TooltipItem<"bar">[]) => {
              const balance = seriesOf(data, "balance")[items[0]?.dataIndex ?? -1]
              if (balance === null || balance === undefined || !options.words.balance) return ""
              return t(options.words.balance, { amount: signedPicoins(balance, options.locale) })
            },
          },
        },
      },
    },
  }
}

export function circulationConfiguration(
  data: ChartData,
  options: DrawOptions,
): ChartConfiguration<"line", Point[], string> {
  return {
    type: "line",
    data: {
      labels: data.labels,
      datasets: [
        {
          label: options.words.series?.circulation ?? "circulation",
          data: seriesOf(data, "circulation"),
          borderColor: options.theme.series.circulation,
          backgroundColor: options.theme.series.circulation,
          borderWidth: LINE_WIDTH,
          pointRadius: 0,
          pointHitRadius: 8,
          spanGaps: false,
        },
      ],
    },
    options: {
      animation: animation(options),
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      scales: { x: categoryAxis(options), y: picoinAxis(options) },
      plugins: {
        tooltip: {
          ...tooltipFrame(options),
          callbacks: {
            title: dayTitle(data.labels),
            label: (item: TooltipItem<"line">) => valueLine(data, options, "circulation", item.dataIndex) ?? "",
          },
        },
      },
    },
  }
}
