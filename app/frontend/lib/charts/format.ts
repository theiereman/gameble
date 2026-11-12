import { picoins } from "../picoins"

export const MINUS = "−"

export function signedPicoins(amount: number, locale: string): string {
  if (amount === 0) return picoins(0, { locale })
  const sign = amount > 0 ? "+" : MINUS
  return sign + picoins(Math.abs(amount), { locale })
}

export function compactTick(value: number, locale: string): string {
  const amount = Math.round(Math.abs(value))
  const figure = picoins(amount, { locale, compact: true })
  return value < 0 && amount > 0 ? MINUS + figure : figure
}

const DECIMAL_SEPARATORS: Readonly<Record<string, string>> = { en: ".", fr: "," }

export function indexValue(value: number, locale: string): string {
  const tenths = Math.round(Math.abs(value) * 10)
  const whole = Math.floor(tenths / 10)
  const tenth = tenths % 10
  const sign = value < 0 && tenths > 0 ? MINUS : ""
  const decimals = tenth === 0 ? "" : `${DECIMAL_SEPARATORS[locale] ?? "."}${tenth}`
  return `${sign}${whole}${decimals}`
}
