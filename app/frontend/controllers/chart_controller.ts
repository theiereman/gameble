import { Controller } from "@hotwired/stimulus"
import type { Chart } from "chart.js"
import { configurationFor, seriesKeys } from "../lib/charts/configurations"
import { resolveTheme } from "../lib/charts/theme"
import type { ChartData, ChartWords } from "../lib/charts/types"
import { motionReduced, onMotionChange } from "../lib/motion"

export default class extends Controller<HTMLElement> {
  static targets = ["canvas"]
  static values = { series: Object, words: Object }

  declare readonly canvasTarget: HTMLCanvasElement
  declare readonly hasCanvasTarget: boolean
  declare readonly seriesValue: ChartData
  declare readonly wordsValue: ChartWords

  private chart: Chart | null = null
  private drawing = 0
  private connected = false
  private stopWatchingMotion: (() => void) | null = null

  connect(): void {
    this.connected = true
    this.stopWatchingMotion = onMotionChange(() => void this.draw())
    void this.draw()
  }

  disconnect(): void {
    this.connected = false
    this.drawing += 1
    this.stopWatchingMotion?.()
    this.stopWatchingMotion = null
    this.chart?.destroy()
    this.chart = null
  }

  seriesValueChanged(): void {
    if (this.connected) void this.draw()
  }

  private async draw(): Promise<void> {
    const run = ++this.drawing
    const [{ Chart }] = await Promise.all([import("../lib/charts/registration"), document.fonts?.ready])
    if (run !== this.drawing || !this.hasCanvasTarget) return

    const data = this.seriesValue
    const style = getComputedStyle(this.element)
    const configuration = configurationFor(data, {
      theme: resolveTheme((token) => style.getPropertyValue(token), seriesKeys(data)),
      words: this.wordsValue,
      locale: document.documentElement.lang || "en",
      reducedMotion: motionReduced(),
    })
    if (!configuration) return

    this.chart?.destroy()
    this.chart = new Chart(this.canvasTarget, configuration)
  }
}
