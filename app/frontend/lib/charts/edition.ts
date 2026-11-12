import type { ChartConfiguration, TooltipItem } from "chart.js"
import { t } from "../i18n"
import { picoins } from "../picoins"
import { animation, dayTitle, labelFont, LINE_WIDTH, picoinAxis, tooltipFrame } from "./base"
import { RARITY_KEYS, RARITY_SHAPES } from "./rarity"
import type { ChartData, DrawOptions, Point } from "./types"

export const SALE_RADIUS = 5
export const SALE_RING = 2
export const FLOOR_DASH = [6, 4]

type XY = { x: number; y: number }

type RarityKey = (typeof RARITY_KEYS)[number]

export function saleKey(data: ChartData): RarityKey {
  return RARITY_KEYS.find((key) => key in data.series) ?? "common"
}

export function points(times: readonly number[], values: readonly Point[] = []): XY[] {
  return times.flatMap((x, index) => {
    const y = values[index]
    return y === null || y === undefined ? [] : [{ x, y }]
  })
}

export function dayTick(locale: string): (value: number | string) => string {
  const format = new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", timeZone: "UTC" })
  return (value) => format.format(new Date(Number(value)))
}

export function editionConfiguration(data: ChartData, options: DrawOptions): ChartConfiguration<"scatter", XY[]> {
  const times = data.x ?? []
  const sale = saleKey(data)
  const shape = RARITY_SHAPES[sale]
  const words = options.words.series ?? {}
  const datasets: ChartConfiguration<"scatter", XY[]>["data"]["datasets"] = [
    {
      label: words[sale] ?? sale,
      data: points(times, data.series[sale]),
      pointStyle: shape.style,
      pointRadius: SALE_RADIUS,
      pointHoverRadius: SALE_RADIUS + 1,
      backgroundColor: shape.hollow ? options.theme.panel : options.theme.series[sale],
      borderColor: shape.hollow ? options.theme.series[sale] : options.theme.panel,
      borderWidth: SALE_RING,
    },
  ]
  if (data.series.average) {
    datasets.push({
      label: words.average ?? "average",
      data: points(times, data.series.average),
      showLine: true,
      stepped: "after",
      borderColor: options.theme.series.average,
      borderWidth: LINE_WIDTH,
      pointRadius: 0,
      pointHitRadius: 8,
    })
  }
  datasets.push({
    label: words.floor ?? "floor",
    data: points(times, data.series.floor),
    showLine: true,
    borderColor: options.theme.series.floor,
    borderWidth: LINE_WIDTH,
    borderDash: FLOOR_DASH,
    pointRadius: 0,
    pointHitRadius: 0,
  })

  return {
    type: "scatter",
    data: { datasets },
    options: {
      animation: animation(options),
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "nearest", intersect: false },
      scales: {
        x: {
          type: "linear",
          grid: { display: false },
          border: { color: options.theme.grid },
          ticks: {
            color: options.theme.axisText,
            font: labelFont(options),
            maxTicksLimit: 4,
            callback: dayTick(options.locale),
          },
        },
        y: picoinAxis(options),
      },
      plugins: {
        tooltip: {
          ...tooltipFrame(options),
          filter: (item: TooltipItem<"scatter">) => item.dataset.label !== (words.floor ?? "floor"),
          callbacks: {
            title: (items: ReadonlyArray<TooltipItem<"scatter">>) => {
              const x = items[0]?.parsed.x
              return dayTitle(data.labels)([{ dataIndex: x === undefined || x === null ? -1 : times.indexOf(x) }])
            },
            label: (item: TooltipItem<"scatter">) =>
              options.words.tooltip
                ? t(options.words.tooltip, {
                    series: item.dataset.label ?? "",
                    value: picoins(item.parsed.y ?? 0, { locale: options.locale }),
                  })
                : "",
          },
        },
      },
    },
  }
}
