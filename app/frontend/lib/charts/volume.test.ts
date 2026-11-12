import { describe, expect, it } from "vitest"
import { configurationFor } from "./configurations"
import type { ChartData, ChartTheme, DrawOptions } from "./types"
import { translucent } from "./volume"

const theme: ChartTheme = {
  series: { volume: "#f4c542" },
  text: "#ffffff",
  axisText: "#999999",
  grid: "#333333",
  tooltipBackground: "#111111",
  tooltipBorder: "#444444",
  panel: "#000000",
  fontFamily: "monospace",
}

const options = (): DrawOptions => ({ theme, words: {}, locale: "fr", reducedMotion: false })

const volume: ChartData = {
  kind: "volume",
  labels: ["10 nov.", "11 nov.", "12 nov."],
  series: { volume: [1200, 0, 800] },
}

describe("volume configuration", () => {
  it("fills the area under one line from zero, without axes, tooltip or events", () => {
    const configuration = configurationFor(volume, options()) as unknown as {
      type: string
      data: { datasets: Array<{ fill: string; borderColor: string; backgroundColor: string }> }
      options: { events: string[]; scales: { y: { beginAtZero: boolean; display: boolean } } }
    }

    expect(configuration.type).toBe("line")
    expect(configuration.data.datasets[0]).toMatchObject({
      fill: "origin",
      borderColor: "#f4c542",
      backgroundColor: "#f4c5422e",
    })
    expect(configuration.options.events).toEqual([])
    expect(configuration.options.scales.y).toMatchObject({ beginAtZero: true, display: false })
  })

  it("marks only the last day", () => {
    const configuration = configurationFor(volume, options()) as unknown as {
      data: { datasets: Array<{ pointRadius: number[] }> }
    }

    expect(configuration.data.datasets[0]?.pointRadius).toEqual([0, 0, 3])
  })

  it("leaves the area unfilled when the colour is not a plain hex value", () => {
    expect(translucent("CanvasText")).toBe("transparent")
  })
})
