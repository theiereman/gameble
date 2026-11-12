import type { ChartTheme } from "./types"

export const SERIES_TOKENS: Readonly<Record<string, string>> = {
  minted: "--color-chart-minted",
  destroyed: "--color-chart-destroyed",
  circulation: "--color-text-max",
  common: "--color-rarity-commune",
  uncommon: "--color-rarity-peu-commune",
  rare: "--color-rarity-rare",
  epic: "--color-rarity-epique",
  legendary: "--color-rarity-legendaire",
}

const CHROME_TOKENS = {
  text: "--color-text",
  axisText: "--color-muted",
  grid: "--color-line-soft",
  tooltipBackground: "--color-panel-raised",
  tooltipBorder: "--color-line",
  panel: "--color-panel",
  fontFamily: "--font-family-jetbrains-mono",
} as const

export type ReadToken = (name: string) => string

export function resolveTheme(read: ReadToken, keys: readonly string[]): ChartTheme {
  const series: Record<string, string> = {}
  for (const key of keys) {
    const token = SERIES_TOKENS[key]
    if (token) series[key] = read(token).trim()
  }
  const chrome = Object.fromEntries(
    Object.entries(CHROME_TOKENS).map(([name, token]) => [name, read(token).trim()]),
  ) as Record<keyof typeof CHROME_TOKENS, string>
  return { series, ...chrome }
}
