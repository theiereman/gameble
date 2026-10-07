// The trade board island's rules (story 5.7; EXPERIENCE.md, Card picker,
// Quantity stepper, Remove): a side holds at most four different cards,
// each with 1 to its maximum copies (the player's free copies, or what the
// friend holds). Pure: no DOM, no React.

/** A card on a side: its key (slug and season, AD-15) and its copies. */
export type Line = { key: string; quantity: number }

/** A side's count: different cards and copies. */
export type SideCount = { cards: number; copies: number }

export const MAX_CARDS = 4

/** The copies that may be placed of each card, by key (absent: none). */
export type Maxima = ReadonlyMap<string, number>

/**
 * The lines a side starts with: each card the holder still holds, its
 * quantity lowered to its maximum; a card whose maximum fell to 0 (copies
 * since reserved or traded away) starts removed. At most four, in order.
 */
export function initialLines(lines: readonly Line[], maxima: Maxima): Line[] {
  const seen = new Set<string>()
  const result: Line[] = []
  for (const line of lines) {
    const max = maxima.get(line.key) ?? 0
    if (max < 1 || seen.has(line.key) || result.length >= MAX_CARDS) continue
    seen.add(line.key)
    result.push({ key: line.key, quantity: clamp(line.quantity, 1, max) })
  }
  return result
}

export type Toggle = { lines: Line[]; refused: boolean }

/**
 * Picking a card: a picked card is removed; a new one joins with 1 copy,
 * unless four are already there (`refused`, nothing changes) or none is
 * free (nothing changes).
 */
export function toggle(lines: readonly Line[], key: string, max: number): Toggle {
  if (lines.some((line) => line.key === key)) return { lines: remove(lines, key), refused: false }
  if (max < 1) return { lines: [...lines], refused: false }
  if (lines.length >= MAX_CARDS) return { lines: [...lines], refused: true }
  return { lines: [...lines, { key, quantity: 1 }], refused: false }
}

/** A card's copies set to `quantity`, kept within 1 and `max`. */
export function setQuantity(lines: readonly Line[], key: string, quantity: number, max: number): Line[] {
  return lines.map((line) => (line.key === key ? { key, quantity: clamp(quantity, 1, Math.max(1, max)) } : line))
}

export function remove(lines: readonly Line[], key: string): Line[] {
  return lines.filter((line) => line.key !== key)
}

export function sideCount(lines: readonly Line[]): SideCount {
  return { cards: lines.length, copies: lines.reduce((sum, line) => sum + line.quantity, 0) }
}

/**
 * What a key does in a quantity stepper (a spinbutton): +1 for ArrowUp,
 * ArrowRight and "+", -1 for ArrowDown, ArrowLeft and "-", the minimum for
 * Home, the maximum for End; null for any other key.
 */
export function stepperKey(key: string): 1 | -1 | "min" | "max" | null {
  switch (key) {
    case "ArrowUp":
    case "ArrowRight":
    case "+":
    case "=":
      return 1
    case "ArrowDown":
    case "ArrowLeft":
    case "-":
    case "_":
      return -1
    case "Home":
      return "min"
    case "End":
      return "max"
    default:
      return null
  }
}

/**
 * Where an arrow key moves the focus in the picker's grid of `count` cards
 * laid out in `columns` columns: Left and Right by one, Up and Down by a
 * row (staying put past an edge), Home and End to the first and last card;
 * null for any other key.
 */
export function gridMove(index: number, key: string, count: number, columns: number): number | null {
  if (count < 1) return null
  const width = Math.max(1, columns)
  const target = (() => {
    switch (key) {
      case "ArrowLeft":
        return index - 1
      case "ArrowRight":
        return index + 1
      case "ArrowUp":
        return index - width
      case "ArrowDown":
        return index + width
      case "Home":
        return 0
      case "End":
        return count - 1
      default:
        return null
    }
  })()
  if (target === null) return null
  return target < 0 || target >= count ? index : target
}

/** How many of the items, by their top offsets in layout order, sit on the first row. */
export function columnsOf(tops: readonly number[]): number {
  if (tops.length === 0) return 1
  const first = tops[0]
  const columns = tops.findIndex((top) => Math.abs(top - first) > 1)
  return columns === -1 ? tops.length : columns
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, Math.trunc(value)))
}
