export type MenuKeyEvent = Pick<KeyboardEvent, "key" | "code" | "ctrlKey" | "altKey" | "metaKey" | "repeat">

export function menuDigit(event: MenuKeyEvent): string | undefined {
  if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return undefined
  if (/^[1-9]$/.test(event.key)) return event.key
  return /^Digit([1-9])$/.exec(event.code)?.[1]
}
