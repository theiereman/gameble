// The keys of a keyboard event that name a menu item.
export type MenuKeyEvent = Pick<KeyboardEvent, "key" | "code" | "ctrlKey" | "altKey" | "metaKey" | "repeat">

// The menu item number a key press names, "1" to "9", or undefined. The
// digit is read from the key, or from the physical digit row for layouts
// that type digits with Shift (AZERTY); never from the numpad's code, whose
// keys are arrows with NumLock off. A press with Ctrl, Alt or Meta, or held
// down, names nothing.
export function menuDigit(event: MenuKeyEvent): string | undefined {
  if (event.ctrlKey || event.metaKey || event.altKey || event.repeat) return undefined
  if (/^[1-9]$/.test(event.key)) return event.key
  return /^Digit([1-9])$/.exec(event.code)?.[1]
}
