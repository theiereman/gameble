import {
  arming,
  cardsDealt,
  openingAnswered,
  openingEnded,
  openingStarted,
  resultHeadShown,
  revealMarked,
} from "./booster_opening"
import { lock, start, unlock } from "./booster_state"
import type { BoosterBank, BoosterStart, BoosterState } from "./booster_types"
import type { Rarity } from "./card_types"
import type { OpeningAnswer, OpeningCard, OpeningSetTier } from "./opening"

export const bank = (available: number, extra: Partial<BoosterBank> = {}): BoosterBank => ({
  available,
  special: 0,
  openable: available,
  reserveFull: false,
  nextSpecialKind: null,
  nextAvailableAt: "2026-10-26T12:00:00.000Z",
  serverTime: "2026-10-26T11:00:00.000Z",
  nextPackSize: available > 0 ? 5 : null,
  ...extra,
})

export const cardOf = (tier: Rarity, slug: string = tier): OpeningCard => ({
  slug,
  season: 1,
  tier,
  coverUrl: "",
  title: slug,
  year: 2020,
  label: slug,
  faces: { s: "", m: "", xl: "" },
})

export const VALVE: OpeningSetTier = {
  kind: "studio",
  key: "valve",
  name: "Valve",
  tier: "complete",
  required: 1,
  held: 1,
  total: 1,
  thresholds: [],
  url: "/en/library/studio/valve",
}

export const answerOf = (tiers: Rarity[], setTiers: OpeningSetTier[] = [], available = 1): OpeningAnswer => ({
  pack: { token: "pack-token", kind: "regular", cardBack: "standard", url: "/pack" },
  cards: tiers.map((tier, index) => cardOf(tier, `${tier}-${index}`)),
  bank: {
    available,
    special: 0,
    openable: available,
    reserveFull: false,
    nextSpecialKind: null,
    nextAvailableAt: null,
    scheduledAt: [],
    nextPackSize: available > 0 ? 5 : null,
  },
  serverTime: "2026-10-26T11:00:01.000Z",
  tierCountsBefore: { common: 3, uncommon: 0, rare: 0, epic: 0, legendary: 0 },
  setTiers,
  unlockedCardBacks: [],
})

export const startWith = (overrides: Partial<BoosterStart> = {}): BoosterState =>
  start({
    bank: bank(2),
    reserve: "standard",
    opened: null,
    layout: "wide",
    now: 1000,
    celebrationRemembered: false,
    preview: false,
    ...overrides,
  })

export const FIVE: Rarity[] = ["common", "uncommon", "rare", "epic", "common"]

export const dealt = (
  tiers: Rarity[] = FIVE,
  overrides: Partial<BoosterStart> = {},
  setTiers: OpeningSetTier[] = [],
): BoosterState => {
  const opening = arming(lock(openingStarted(startWith(overrides))), "key-1")
  return unlock(openingEnded(cardsDealt(resultHeadShown(openingAnswered(opening, answerOf(tiers, setTiers))))))
}

export const revealedAll = (state: BoosterState, now = 0): BoosterState =>
  state.revealed.reduce((next, _, index) => revealMarked(next, index, now), state)
