// The keys of a keyboard event that name a menu item.
export type MenuKeyEvent = Pick<KeyboardEvent, "key" | "code" | "ctrlKey" | "altKey" | "metaKey" | "repeat">

// The menu item number a key press names, "1" to "9", or undefined: read from the key or, for layouts that type digits with Shift (AZERTY),
// from the digit row, never the numpad. A press with Ctrl, Alt or Meta, or held down, names nothing.
export function menuDigit(event: MenuKeyEvent): string | undefined {
  if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return undefined
  if (/^[1-9]$/.test(event.key)) return event.key
  return /^Digit([1-9])$/.exec(event.code)?.[1]
}
