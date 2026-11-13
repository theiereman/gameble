const PLAIN = /^\d+$/
const GROUPED = /^\d{1,3}([ ,\u00A0\u202F])\d{3}(?:\1\d{3})*$/
const SPACES = " \u00A0\u202F"
const THOUSANDS = /\B(?=(\d{3})+(?!\d))/g

const DELIMITERS: Record<string, string> = { en: ",", fr: "\u00A0" }

export type Edit = "insert" | "deleteBackward" | "deleteForward"

export type Typed = Readonly<{ text: string; caret: number }>

export function amountDigits(text: string): string | null {
  const typed = text.trim()
  if (PLAIN.test(typed)) return typed
  const separator = GROUPED.exec(typed)?.[1]
  return separator === undefined ? null : typed.replaceAll(separator, "")
}

export function delimiterOf(locale: string): string {
  return DELIMITERS[locale] ?? DELIMITERS.en
}

export function groupDigits(digits: string, locale: string): string {
  return digits.replace(THOUSANDS, delimiterOf(locale))
}

function separatorsOf(locale: string): string {
  return SPACES + delimiterOf(locale)
}

function digitsOnly(text: string): string {
  return text.replace(/\D/g, "")
}

function onlyDigitsAndSeparators(text: string, locale: string): boolean {
  const separators = separatorsOf(locale)
  return Array.from(text).every((char) => /\d/.test(char) || separators.includes(char))
}

function caretAfterDigits(text: string, count: number): number {
  if (count === 0) return 0
  let seen = 0
  for (let index = 0; index < text.length; index++) {
    if (/\d/.test(text[index]) && ++seen === count) return index + 1
  }
  return text.length
}

function withoutDigitAt(digits: string, index: number): string {
  return index < 0 || index >= digits.length ? digits : digits.slice(0, index) + digits.slice(index + 1)
}

export function regroup(typed: Typed, before: string, edit: Edit, locale: string): Typed | null {
  if (!onlyDigitsAndSeparators(typed.text, locale)) return null

  let digits = digitsOnly(typed.text)
  let digitsBefore = digitsOnly(typed.text.slice(0, typed.caret)).length
  const separatorOnly = digits === digitsOnly(before) && typed.text !== before
  if (separatorOnly && edit === "deleteBackward") {
    digits = withoutDigitAt(digits, digitsBefore - 1)
    digitsBefore = Math.max(digitsBefore - 1, 0)
  } else if (separatorOnly && edit === "deleteForward") {
    digits = withoutDigitAt(digits, digitsBefore)
  }

  const text = groupDigits(digits, locale)
  return { text, caret: caretAfterDigits(text, digitsBefore) }
}

export function editOf(inputType: string | undefined): Edit {
  if (inputType === "deleteContentBackward") return "deleteBackward"
  if (inputType === "deleteContentForward") return "deleteForward"
  return "insert"
}
