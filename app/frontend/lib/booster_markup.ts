import type { BoosterBank } from "./booster_types"
import { RARITIES, type Rarity } from "./card_types"
import {
  SET_TIERS,
  type OpeningAnswer,
  type OpeningCard,
  type OpeningSetTier,
  type SetThreshold,
  type SetTierName,
} from "./opening"

export type Dataset = Readonly<Record<string, string | undefined>>

export type BankValues = {
  available: number
  special: number
  openable: number
  reserveFull: boolean
  nextAvailableAt: string
  serverTime: string
  nextPackSize: number
}

export type OpenedMarkup = {
  pack: Dataset | null
  cards: readonly Dataset[]
  setTiers: readonly Dataset[]
  bank: BoosterBank
}

const NO_COUNTS: Record<Rarity, number> = { common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0 }

const whole = (value: string | undefined): number => Number.parseInt(value ?? "", 10) || 0

const tierOf = (value: string | undefined): Rarity =>
  RARITIES.includes(value as Rarity) ? (value as Rarity) : "common"

const setTierOf = (value: string | undefined): SetTierName | null =>
  SET_TIERS.includes(value as SetTierName) ? (value as SetTierName) : null

export function bankFrom({
  available,
  special,
  openable,
  reserveFull,
  nextAvailableAt,
  serverTime,
  nextPackSize,
}: BankValues): BoosterBank {
  return {
    available,
    special,
    openable,
    reserveFull,
    nextAvailableAt: nextAvailableAt || null,
    serverTime,
    nextPackSize: nextPackSize > 0 ? nextPackSize : null,
  }
}

export function cardFrom(data: Dataset): OpeningCard {
  return {
    slug: data.slug ?? "",
    season: whole(data.season),
    tier: tierOf(data.tier),
    coverUrl: data.coverUrl ?? "",
    title: data.title ?? "",
    year: data.year ? whole(data.year) : null,
    label: data.label ?? data.title ?? "",
    faces: { s: "", m: "", xl: "" },
  }
}

export function thresholdsFrom(text: string | undefined): SetThreshold[] {
  return (text ?? "").split(/\s+/).flatMap((pair) => {
    const [name, required] = pair.split(":")
    const tier = setTierOf(name)
    return tier && required ? [{ tier, required: whole(required) }] : []
  })
}

export function setTierFrom(data: Dataset): OpeningSetTier | null {
  const tier = setTierOf(data.tier)
  if (!tier) return null
  return {
    kind: data.kind ?? "",
    key: data.key ?? "",
    name: data.name ?? "",
    tier,
    required: whole(data.required),
    held: whole(data.held),
    total: whole(data.total),
    thresholds: thresholdsFrom(data.thresholds),
    url: data.url ?? "",
  }
}

export function openedFrom({ pack, cards, setTiers, bank }: OpenedMarkup): OpeningAnswer | null {
  if (!pack?.token || cards.length === 0) return null
  return {
    pack: { token: pack.token, kind: pack.kind ?? "", cardBack: pack.cardBack ?? "standard", url: pack.url ?? "" },
    cards: cards.map(cardFrom),
    bank: {
      available: bank.available,
      special: bank.special,
      openable: bank.openable,
      reserveFull: bank.reserveFull,
      nextAvailableAt: bank.nextAvailableAt,
      scheduledAt: [],
      nextPackSize: bank.nextPackSize,
    },
    serverTime: bank.serverTime,
    tierCountsBefore: { ...NO_COUNTS },
    setTiers: setTiers.flatMap((data) => setTierFrom(data) ?? []),
    unlockedCardBacks: [],
  }
}
