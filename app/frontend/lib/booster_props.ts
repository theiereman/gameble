// The booster island's props, as BoostersHelper#booster_props writes them:
// the URLs, the bank, the tiers' names and icons, and every word; and the
// island's phase and status, which its view draws. Types only, so the
// entrypoint can name them without loading the island.
import type { Rarity } from "./card_types"
import type { Template } from "./i18n"

/** Where the island is: the canister sealed, the reserve empty, an opening running, cards dealt. */
export type BoosterPhase = "sealed" | "empty" | "opening" | "dealt"

/** Where the island says it is: the state line's word. */
export type BoosterStatus = "sealed" | "arming" | "ejecting" | "inventory" | "legendarySignal" | "complete" | "waiting"

/** Every word of the island (`boosters.island`, BoostersHelper#booster_props). */
export type BoosterStrings = {
  kicker: string
  kickerPlain: string
  title: string
  cardsPerPack: string
  inReserve: string
  reserveCount: Template
  state: string
  states: Record<BoosterStatus, string>
  reserve: string
  nextIn: string
  nextAt: string
  reserveFull: string
  open: string
  openNext: string
  reserveEmpty: string
  emptyNext: string
  revealAll: string
  back: string
  revealedCount: string
  canisterLabel: string
  canisterLabelPlain: string
  canisterHint: string
  canisterSeason: string
  result: string
  hintRemaining: Template
  hintDone: Template
  faceDown: string
  faceUp: string
  announceCard: string
  summary: Template
  summaryTier: Template
  legendaryBanner: string
  bannerLine: string
  refusedTitle: string
  failed: string
  islandFailed: string
  reload: string
  // The phone.
  stripTitle: string
  stripTitlePlain: string
  canisterHintTouch: string
  canisterFacts: Template
  hintTap: string
  hintSwipe: string
  store: string
  faceUpStore: string
  tray: string
  trayLabel: string
  trayCount: string
  traySlot: string
  zoomLine: string
  seeCard: string
  close: string
  zoomTip: string
}

export type BoosterBank = {
  available: number
  reserveFull: boolean
  nextAvailableAt: string | null
  serverTime: string
  /** The card count of the pack the next opening opens (3 for a daily bonus pack first in line), null when none is available. */
  nextPackSize: number | null
}

export type BoosterProps = {
  /** The opening exchange's URL (packs#create). */
  openUrl: string
  hubUrl: string
  /** A card's page, its slug in place of SLUG. */
  cardUrl: string
  /** The locale's digit delimiter. */
  delimiter: string
  /** The published season's number, null without one. */
  season: number | null
  /** The cards of a regular pack: the size shown when the next pack's is not known. */
  packSize: number
  bank: BoosterBank
  rarityNames: Record<Rarity, string>
  /** Each tier's pixel icon, as HTML. */
  rarityIcons: Record<Rarity, string>
  strings: BoosterStrings
}
