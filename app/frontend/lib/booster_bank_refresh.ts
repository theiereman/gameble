import { bankFetchOwed, bankFetched, countdownAtZero, type BoosterState } from "./booster"
import { fetchBank } from "./booster_bank"
import type { Transition } from "./booster_host"
import { refreshPage } from "./booster_page"

export type BankRefreshHost = Readonly<{
  state: () => BoosterState | undefined
  current: () => BoosterState
  bankUrl: string
  disposed: () => boolean
  apply: (transition: Transition) => BoosterState
}>

export class BankRefresh {
  constructor(private readonly host: BankRefreshHost) {}

  async refresh(): Promise<void> {
    const generation = this.host.current().bankGeneration
    const fresh = await fetchBank({ url: this.host.bankUrl })
    if (!fresh || this.host.disposed()) return
    this.host.apply((s) => bankFetched(s, fresh, generation))
  }

  atZero(): void {
    const state = this.host.state()
    if (this.host.disposed() || !state) return
    const action = countdownAtZero(state)
    if (action === "page") refreshPage()
    else if (action === "bank") void this.refresh()
    else this.host.apply(bankFetchOwed)
  }
}
