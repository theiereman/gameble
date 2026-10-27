export const TIER_AT_ATTRIBUTE = "data-tier-at"
export const PLACED_CLASS = "is-placed"

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

export function placeTicks(elements: Iterable<Placeable>): void {
  for (const element of elements) {
    const at = tierAt(element.getAttribute(TIER_AT_ATTRIBUTE))
    if (at === null) continue
    element.style.setProperty("--at", String(at))
    element.classList.add(PLACED_CLASS)
  }
}
