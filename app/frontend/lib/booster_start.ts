import { start, type BoosterState, type Reserve } from "./booster"
import { bankFrom, openedFrom, type BankValues, type Dataset } from "./booster_markup"
import { celebrationRemembered, readLayout } from "./booster_page"

export type ServerMarkup = Readonly<{
  bank: BankValues
  reserve: Reserve
  pack: Dataset | null
  cards: readonly Dataset[]
  setTiers: readonly Dataset[]
}>

export function startingState({ bank: bankValues, reserve, pack, cards, setTiers }: ServerMarkup): BoosterState {
  const bank = bankFrom(bankValues)
  return start({
    bank,
    reserve,
    opened: openedFrom({ pack, cards, setTiers, bank }),
    layout: readLayout(),
    now: performance.now(),
    celebrationRemembered: celebrationRemembered(),
    preview: document.documentElement.hasAttribute("data-turbo-preview"),
  })
}
