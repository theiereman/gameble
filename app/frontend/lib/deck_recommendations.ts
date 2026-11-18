import { BY_POPULARITY, callValue, sortRefs } from "./deck_collection_order"
import type { DeckState } from "./deck_editor"

const RECOMMENDED = 12
const KNOWN_FROM = 60

/* The cards to try next: for each call the deck lacks, the strongest well-known cards, taken in turn. */
export function recommendedRefs(state: DeckState): string[] {
  if (!state.slots.includes(null)) return []
  const placed = state.slots.filter((ref): ref is string => ref !== null)
  const games = new Set(placed.map((ref) => state.entries[ref]?.game))
  const open = state.order.filter((ref) => {
    const entry = state.entries[ref]
    return entry?.availability === "available" && !placed.includes(ref) && !games.has(entry.game)
  })
  const gaps = (state.coverage ?? []).filter((cell) => cell.gap).map((cell) => cell.call)
  const known = gaps.filter((call) => call !== "popularity-low")
  const calls = known.length ? known : gaps.length ? gaps : (state.coverage ?? []).map((cell) => cell.call)
  const popularity = (ref: string): number => callValue(state.entries[ref]?.percentiles ?? {}, BY_POPULARITY) ?? 0
  const queues = calls.map((call) => {
    const ranked = sortRefs(state.entries, open, call).filter(
      (ref) => callValue(state.entries[ref]?.percentiles ?? {}, call) !== null,
    )
    const wellKnown = ranked.filter((ref) => popularity(ref) >= KNOWN_FROM)
    return call === "popularity-low" || wellKnown.length === 0 ? ranked : wellKnown
  })
  const picked = new Set<string>()
  for (let round = 0; picked.size < RECOMMENDED && queues.some((queue) => queue.length > round); round++) {
    for (const queue of queues) {
      const next = queue.find((ref) => !picked.has(ref) && !games.has(state.entries[ref]?.game))
      if (!next || picked.size >= RECOMMENDED) continue
      picked.add(next)
      games.add(state.entries[next]?.game)
    }
  }
  return [...picked]
}
