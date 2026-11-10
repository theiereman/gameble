const GROUP = 4
const LENGTH = GROUP * 2

export type Formatted = { value: string; caret: number }

export function formatFriendCode(raw: string, caret: number, deleting: boolean): Formatted {
  const charsBeforeCaret = significant(raw.slice(0, caret)).length
  const chars = significant(raw).slice(0, LENGTH)
  const grouped = chars.length > GROUP ? `${chars.slice(0, GROUP)}-${chars.slice(GROUP)}` : chars
  const value = chars.length === GROUP && !deleting ? `${grouped}-` : grouped
  return { value, caret: caretAfter(Math.min(charsBeforeCaret, chars.length), value) }
}

function significant(text: string): string {
  return text.toUpperCase().replace(/[^0-9A-Z]/g, "")
}

function caretAfter(chars: number, value: string): number {
  if (chars === 0) return 0
  let seen = 0
  for (let index = 0; index < value.length; index++) {
    if (value[index] !== "-") seen++
    if (seen === chars) return value[index + 1] === "-" && index + 2 === value.length ? index + 2 : index + 1
  }
  return value.length
}
