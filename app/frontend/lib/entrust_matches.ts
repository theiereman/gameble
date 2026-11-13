import { RARITIES, type Rarity } from "./card_types"
import type { Copy } from "./entrust"

function copyOf(row: unknown): Copy | null {
  if (typeof row !== "object" || row === null) return null
  const { ref, title, rarity, season, free, owned, value } = row as Record<string, unknown>
  if (
    typeof ref !== "string" ||
    typeof title !== "string" ||
    typeof rarity !== "string" ||
    !RARITIES.includes(rarity as Rarity)
  )
    return null
  const numbers = [season, free, owned, value]
  if (!numbers.every((number) => typeof number === "number" && Number.isFinite(number))) return null
  return {
    ref,
    title,
    rarity: rarity as Rarity,
    season: season as number,
    free: free as number,
    owned: owned as number,
    value: value as number,
  }
}

// The rows the server answers for every edition the filter keeps; a malformed answer is no answer.
export function matchesOf(body: unknown): Copy[] | null {
  if (!Array.isArray(body)) return null
  const copies = body.map(copyOf)
  return copies.every((copy) => copy !== null) ? (copies as Copy[]) : null
}

export async function fetchMatches(url: string): Promise<Copy[] | null> {
  try {
    const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    return response.ok ? matchesOf(await response.json()) : null
  } catch {
    return null
  }
}
