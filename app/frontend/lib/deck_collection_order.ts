export const BY_TITLE = "title"
export const ALL_TRUMPS = "all"

export type Percentiles = Readonly<Record<string, number | null>>

export type Ranked = { percentiles: Percentiles; trump: string }

type Entries = Readonly<Record<string, Ranked | undefined>>

export function callValue(percentiles: Percentiles, call: string): number | null {
  const [stat, direction] = call.split("-")
  const percentile = stat === undefined ? undefined : percentiles[stat]
  if (typeof percentile !== "number") return null
  return direction === "low" ? 100 - percentile : percentile
}

export function sortRefs(entries: Entries, order: readonly string[], sort: string): string[] {
  if (sort === BY_TITLE) return [...order]
  const ranked = order.map((ref, index) => {
    const entry = entries[ref]
    return { ref, index, value: entry ? callValue(entry.percentiles, sort) : null }
  })
  ranked.sort((a, b) => {
    if (a.value === b.value) return a.index - b.index
    if (a.value === null) return 1
    if (b.value === null) return -1
    return b.value - a.value
  })
  return ranked.map(({ ref }) => ref)
}

export function visibleRefs(entries: Entries, order: readonly string[], trump: string): string[] {
  return trump === ALL_TRUMPS ? [...order] : order.filter((ref) => entries[ref]?.trump === trump)
}
