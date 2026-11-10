import { formatNumber } from "./i18n"

type Forms = { delimiter: string; separator: string }

const FORMS: Record<string, Forms> = {
  en: { delimiter: ",", separator: "." },
  fr: { delimiter: " ", separator: "," },
}

const COMPACT_UNITS: Array<[number, string]> = [
  [1_000_000, "M"],
  [1_000, "k"],
]

export type PicoinsOptions = { locale?: string; compact?: boolean }

export function picoins(amount: number, { locale = "en", compact = false }: PicoinsOptions = {}): string {
  if (!Number.isSafeInteger(amount) || amount < 0) throw new RangeError(`not a PiCoin amount: ${String(amount)}`)

  const { delimiter, separator } = FORMS[locale] ?? FORMS.en
  if (!compact || amount < 1_000) return formatNumber(amount, delimiter)

  const [divisor, suffix] = COMPACT_UNITS.find(([threshold]) => amount >= threshold)!
  const tenths = Math.floor((amount * 10) / divisor)
  const whole = Math.floor(tenths / 10)
  const tenth = tenths % 10
  const number = tenth === 0 ? formatNumber(whole, delimiter) : `${formatNumber(whole, delimiter)}${separator}${tenth}`
  return `${number}${suffix}`
}
