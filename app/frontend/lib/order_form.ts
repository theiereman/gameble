import { amountDigits } from "./amount"
import { t } from "./i18n"
import { picoins } from "./picoins"

export const RARITIES = ["common", "uncommon", "rare", "epic", "legendary"] as const

export type Rarity = (typeof RARITIES)[number]

export type Minimums = Record<Rarity, number>

export type OrderStrings = {
  some: string
  all: string
  none: string
  reached: Record<Rarity, string>
  next: Record<Rarity, string>
}

export function parsePrice(text: string): number | null {
  const digits = amountDigits(text)
  if (digits === null) return null
  const price = Number(digits)
  return Number.isSafeInteger(price) && price > 0 ? price : null
}

export function reachedRarities(minimums: Minimums, price: number | null): Rarity[] {
  return price === null ? [] : RARITIES.filter((rarity) => minimums[rarity] <= price)
}

export function nextRarity(minimums: Minimums, price: number | null): Rarity | null {
  const reached = reachedRarities(minimums, price)
  return RARITIES.filter((rarity) => !reached.includes(rarity)).reduce<Rarity | null>(
    (lowest, rarity) => (lowest === null || minimums[rarity] < minimums[lowest] ? rarity : lowest),
    null,
  )
}

export function sentence(strings: OrderStrings, minimums: Minimums, price: number | null, locale: string): string {
  const upcoming = nextRarity(minimums, price)
  if (upcoming === null) return strings.all

  const vars = { next: strings.next[upcoming], amount: picoins(minimums[upcoming], { locale }) }
  const reached = reachedRarities(minimums, price)
  if (reached.length === 0) return t(strings.none, vars)

  const words = new Intl.ListFormat(locale, { type: "conjunction" }).format(
    reached.map((rarity) => strings.reached[rarity]),
  )
  return t(strings.some, { ...vars, reached: words })
}
