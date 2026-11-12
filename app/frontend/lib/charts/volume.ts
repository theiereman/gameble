import type { ChartConfiguration } from "chart.js"
import { LINE_WIDTH } from "./base"
import type { ChartData, DrawOptions, Point } from "./types"

const FILL_ALPHA = "2e"
const END_POINT_RADIUS = 3
const HEX_COLOR = /^#[\da-f]{6}$/i

export function translucent(color: string): string {
  return HEX_COLOR.test(color) ? `${color}${FILL_ALPHA}` : "transparent"
}

export function volumeConfiguration(
  data: ChartData,
  options: DrawOptions,
): ChartConfiguration<"line", Point[], string> {
  const values = data.series.volume ?? []
  const color = options.theme.series.volume ?? options.theme.text
  const last = values.length - 1
  return {
    type: "line",
    data: {
      labels: data.labels,
      datasets: [
        {
          data: values,
          borderColor: color,
          backgroundColor: translucent(color),
          fill: "origin",
          borderWidth: LINE_WIDTH,
          pointStyle: "rect",
          pointRadius: values.map((_, index) => (index === last ? END_POINT_RADIUS : 0)),
          pointBackgroundColor: color,
          pointBorderWidth: 0,
        },
      ],
    },
    options: {
      animation: false,
      responsive: true,
      maintainAspectRatio: false,
      events: [],
      layout: { padding: END_POINT_RADIUS },
      scales: {
        x: { type: "category", display: false },
        y: { type: "linear", display: false, beginAtZero: true },
      },
      plugins: { tooltip: { enabled: false } },
    },
  }
}
