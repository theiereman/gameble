import type { BoosterState } from "./booster"
import { CardExit } from "./booster_exit"
import { CardMarket, type BoosterMarket } from "./booster_market"
import type { BoosterStageHost } from "./booster_host"
import type { BoosterStrings } from "./booster_render_host"
import { RevealSequence } from "./booster_reveal"
import { RevealAll } from "./booster_reveal_all"
import { CardStore } from "./booster_store"
import type { Rarity } from "./card_types"

export type GameplayConfig = Readonly<{
  stage: BoosterStageHost
  strings: BoosterStrings
  delimiter: string
  cardUrl: string
  repostUrl: string
  market: BoosterMarket
  state: () => BoosterState | undefined
  rarityNames: () => Record<Rarity, string>
  whenIdle: () => void
}>

export type Gameplay = Readonly<{
  reveals: RevealSequence
  everyReveal: RevealAll
  cardStore: CardStore
  cardExit: CardExit
  cardMarket: CardMarket
}>

export function gameplayFor({
  stage,
  strings,
  delimiter,
  cardUrl,
  repostUrl,
  market,
  state,
  rarityNames,
  whenIdle,
}: GameplayConfig): Gameplay {
  const reveals = new RevealSequence({
    ...stage,
    legendarySignal: strings.legendarySignal,
    announceCardLine: strings.announceCard,
    rarityNames,
  })
  const cardStore = new CardStore({ ...stage, whenIdle })
  const cardExit = new CardExit({
    state,
    cardUrl,
    repostUrl,
    reposted: strings.reposted,
    repostFailed: strings.repostFailed,
  })
  const everyReveal = new RevealAll({
    ...stage,
    summary: strings.summary,
    summaryTier: strings.summaryTier,
    delimiter,
    rarityNames,
    reveal: (index, fromAll, options) => reveals.reveal(index, fromAll, options),
    store: (index, fromAll) => cardStore.store(index, fromAll),
    whenIdle,
  })
  const cardMarket = new CardMarket({ market, state, apply: stage.apply, failed: strings.marketFailed })
  return { reveals, everyReveal, cardStore, cardExit, cardMarket }
}
