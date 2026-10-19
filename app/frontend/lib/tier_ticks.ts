// Where a set's tier tick sits on its bar: the share of the set its tier
// asks for, written by the server as a data attribute and turned into a
// custom property, since server HTML carries no style attribute.

export const TIER_AT_ATTRIBUTE = "data-tier-at"
export const PLACED_CLASS = "is-placed"

/** The tick's place from 0 to 1, or null for a value that is not one. */
export function tierAt(raw: string | null | undefined): number | null {
  if (raw === null || raw === undefined || raw.trim() === "") return null
  const at = Number(raw)
  return Number.isFinite(at) && at >= 0 && at <= 1 ? at : null
}

export type Placeable = {
  getAttribute(name: string): string | null
  style: { setProperty(name: string, value: string): void }
  classList: { add(name: string): void }
}

/** Sets `--at` on every tick and figure that carries a valid place and shows it; the others stay hidden. */
export function placeTicks(elements: Iterable<Placeable>): void {
  for (const element of elements) {
    const at = tierAt(element.getAttribute(TIER_AT_ATTRIBUTE))
    if (at === null) continue
    element.style.setProperty("--at", String(at))
    element.classList.add(PLACED_CLASS)
  }
}
