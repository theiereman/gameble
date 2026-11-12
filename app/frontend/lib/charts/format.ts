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
