import { start, type BoosterState } from "./booster"
import { bankFrom, openedFrom, type BankValues, type Dataset } from "./booster_markup"
import { celebrationRemembered, readLayout } from "./booster_page"

export type ServerMarkup = Readonly<{
  bank: BankValues
  pack: Dataset | null
  cards: readonly Dataset[]
  setTiers: readonly Dataset[]
}>

export function startingState({ bank: bankValues, pack, cards, setTiers }: ServerMarkup): BoosterState {
  const bank = bankFrom(bankValues)
  return start({
    bank,
    opened: openedFrom({ pack, cards, setTiers, bank }),
    layout: readLayout(),
    now: performance.now(),
    celebrationRemembered: celebrationRemembered(),
    preview: document.documentElement.hasAttribute("data-turbo-preview"),
  })
}
