import type { BoosterState } from "./booster"
import { CardExit } from "./booster_exit"
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
  state: () => BoosterState | undefined
  rarityNames: () => Record<Rarity, string>
  whenIdle: () => void
}>

export type Gameplay = Readonly<{
  reveals: RevealSequence
  everyReveal: RevealAll
  cardStore: CardStore
  cardExit: CardExit
}>

export function gameplayFor({ stage, strings, delimiter, cardUrl, repostUrl, state, rarityNames, whenIdle }: GameplayConfig): Gameplay {
  const reveals = new RevealSequence({
    ...stage,
    legendarySignal: strings.legendarySignal,
    announceCardLine: strings.announceCard,
    bannerLine: strings.bannerLine,
    rarityNames,
  })
  const cardStore = new CardStore({ ...stage, whenIdle })
  const cardExit = new CardExit({ state, cardUrl, repostUrl, reposted: strings.reposted, repostFailed: strings.repostFailed })
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
  return { reveals, everyReveal, cardStore, cardExit }
}
