import { start, type BoosterState, type Reserve } from "./booster"
import { heldFrom } from "./booster_bank"
import { bankFrom, openedFrom, type BankValues, type Dataset } from "./booster_markup"
import { celebrationRemembered, readLayout } from "./booster_page"
import { loadQueue } from "./opening_queue"

export type ServerMarkup = Readonly<{
  bank: BankValues
  reserve: Reserve
  held: unknown
  pack: Dataset | null
  cards: readonly Dataset[]
  setTiers: readonly Dataset[]
}>

export function startingState({ bank: bankValues, reserve, held, pack, cards, setTiers }: ServerMarkup): BoosterState {
  const bank = bankFrom(bankValues)
  return start({
    bank,
    reserve,
    held: heldFrom(held),
    confirming: loadQueue(),
    opened: openedFrom({ pack, cards, setTiers, bank }),
    layout: readLayout(),
    now: performance.now(),
    celebrationRemembered: celebrationRemembered(),
    preview: document.documentElement.hasAttribute("data-turbo-preview"),
  })
}
