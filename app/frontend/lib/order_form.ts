import { amountDigits } from "./amount"

export function parsePrice(text: string): number | null {
  const digits = amountDigits(text)
  if (digits === null) return null
  const price = Number(digits)
  return Number.isSafeInteger(price) && price > 0 ? price : null
}
