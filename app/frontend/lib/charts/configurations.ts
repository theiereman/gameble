import { rarityIndexConfiguration, sparklineConfiguration } from "./rarity"
import { circulationConfiguration, reactorConfiguration } from "./reactor"
import type { ChartData, DrawnConfiguration, DrawOptions } from "./types"

type Build = (data: ChartData, options: DrawOptions) => unknown

const BUILDERS: Readonly<Record<string, Build>> = {
  reactor: reactorConfiguration,
  circulation: circulationConfiguration,
  rarity_index: rarityIndexConfiguration,
  sparkline: sparklineConfiguration,
}

export function configurationFor(data: ChartData, options: DrawOptions): DrawnConfiguration | null {
  const build = BUILDERS[data.kind]
  return build ? (build(data, options) as DrawnConfiguration) : null
}

export function seriesKeys(data: ChartData): string[] {
  return Object.keys(data.series)
}
