import { Controller } from "@hotwired/stimulus"
import type { Chart } from "chart.js"
import { configurationFor, seriesKeys } from "../lib/charts/configurations"
import { forcedTheme } from "../lib/charts/forced"
import { resolveTheme } from "../lib/charts/theme"
import type { ChartData, ChartTheme, ChartWords } from "../lib/charts/types"
import { motionReduced, onMotionChange } from "../lib/motion"

const NARROW = "(max-width: 719px)"
const FORCED_COLORS = "(forced-colors: active)"

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
  private stopWatching: Array<() => void> = []

  connect(): void {
    this.connected = true
    const redraw = () => void this.draw()
    this.stopWatching = [
      onMotionChange(redraw),
      this.watchMedia(NARROW, redraw),
      this.watchMedia(FORCED_COLORS, redraw),
      this.listen(document, "keydown", (event) => {
        if ((event as KeyboardEvent).key === "Escape") this.closeTooltip()
      }),
      this.listen(document, "pointerdown", (event) => {
        if (!this.element.contains(event.target as Node)) this.closeTooltip()
      }),
    ]
    void this.draw()
  }

  disconnect(): void {
    this.connected = false
    this.drawing += 1
    this.stopWatching.forEach((stop) => stop())
    this.stopWatching = []
    this.chart?.destroy()
    this.chart = null
  }

  seriesValueChanged(): void {
    if (this.connected) void this.draw()
  }

  private async draw(): Promise<void> {
    const run = ++this.drawing
    try {
      const [{ Chart }] = await Promise.all([import("../lib/charts/registration"), document.fonts?.ready])
      if (run !== this.drawing || !this.hasCanvasTarget) return

      const narrow = matchMedia(NARROW).matches
      const forcedColors = matchMedia(FORCED_COLORS).matches
      const configuration = configurationFor(this.seriesValue, {
        theme: this.theme(forcedColors),
        words: this.wordsValue,
        locale: document.documentElement.lang || "en",
        reducedMotion: motionReduced(),
        narrow,
        forcedColors,
      })
      if (!configuration) return this.giveUp()

      this.chart?.destroy()
      this.chart = new Chart(this.canvasTarget, configuration)
      this.element.dataset.chartLayout = narrow ? "narrow" : "wide"
    } catch {
      if (run === this.drawing) this.giveUp()
    }
  }

  private theme(forcedColors: boolean): ChartTheme {
    const style = getComputedStyle(this.element)
    const read = (token: string) => style.getPropertyValue(token)
    const keys = seriesKeys(this.seriesValue)
    return forcedColors ? forcedTheme(keys, read("--font-family-jetbrains-mono")) : resolveTheme(read, keys)
  }

  private giveUp(): void {
    this.chart?.destroy()
    this.chart = null
    this.element.classList.add("chart--failed")
    this.element.querySelector("details")?.setAttribute("open", "")
  }

  private closeTooltip(): void {
    if (!this.chart?.tooltip?.getActiveElements().length) return
    this.chart.tooltip.setActiveElements([], { x: 0, y: 0 })
    this.chart.setActiveElements([])
    this.chart.update()
  }

  private watchMedia(query: string, onChange: () => void): () => void {
    const list = matchMedia(query)
    list.addEventListener("change", onChange)
    return () => list.removeEventListener("change", onChange)
  }

  private listen(target: EventTarget, type: string, handler: (event: Event) => void): () => void {
    target.addEventListener(type, handler)
    return () => target.removeEventListener(type, handler)
  }
}
