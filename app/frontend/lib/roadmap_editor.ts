export type Direction = "up" | "down"

export type KeyReplacements = Record<string, string>

const NEW_KEY = /^new-(\d+)$/

export function isDirection(value: unknown): value is Direction {
  return value === "up" || value === "down"
}

export function nextKey(keys: Iterable<string>): string {
  let highest = 0
  for (const key of keys) {
    const match = NEW_KEY.exec(key)
    if (match) highest = Math.max(highest, Number(match[1]))
  }
  return `new-${highest + 1}`
}

export function neighbourIndex(count: number, index: number, direction: Direction): number | null {
  if (index < 0 || index >= count) return null
  const neighbour = direction === "up" ? index - 1 : index + 1
  return neighbour >= 0 && neighbour < count ? neighbour : null
}

export function indexToFocusAfterRemoval(count: number, index: number): number | null {
  if (count <= 1) return null
  return index < count - 1 ? index + 1 : index - 1
}

export function substituteKeys(value: string, replacements: KeyReplacements): string {
  return Object.entries(replacements).reduce((text, [placeholder, key]) => text.split(placeholder).join(key), value)
}

export function applyKeys(root: Element, replacements: KeyReplacements): void {
  for (const element of [root, ...root.querySelectorAll("*")]) {
    for (const attribute of Array.from(element.attributes)) {
      const value = substituteKeys(attribute.value, replacements)
      if (value !== attribute.value) element.setAttribute(attribute.name, value)
    }
  }
}
