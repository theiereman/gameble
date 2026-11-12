import type { ChartConfiguration } from "chart.js"
import type { Template } from "../i18n"

export type Point = number | null

export type ChartData = {
  kind: string
  labels: string[]
  series: Record<string, Point[]>
  x?: number[]
}

export type ChartWords = {
  series?: Record<string, string>
  tooltip?: Template
  balance?: Template
  tick?: Template
  threshold?: string
}

export type ChartTheme = {
  series: Record<string, string>
  text: string
  axisText: string
  grid: string
  tooltipBackground: string
  tooltipBorder: string
  panel: string
  fontFamily: string
}

export type DrawOptions = {
  theme: ChartTheme
  words: ChartWords
  locale: string
  reducedMotion: boolean
}

export type DrawnConfiguration = ChartConfiguration
