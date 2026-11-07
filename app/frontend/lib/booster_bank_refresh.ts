import {
  bankDue,
  bankFetchOwed,
  bankFetched,
  countdownAtZero,
  dailyCapsuleChosen,
  owedBankTaken,
  reservesUnlocked,
  type BoosterState,
} from "./booster"
import { fetchBank } from "./booster_bank"
import type { Transition } from "./booster_host"
import type { Reserve } from "./booster_types"
import { dispatchGameble } from "./events"

export type BankRefreshHost = Readonly<{
  state: () => BoosterState | undefined
  current: () => BoosterState
  bankUrl: string
  disposed: () => boolean
  apply: (transition: Transition) => BoosterState
  announce: (reserve: Reserve) => void
}>

export class BankRefresh {
  private retryOwed = false
  private readonly retry = (): void => {
    if (!this.retryOwed) return
    this.retryOwed = false
    this.whenDue()
  }
  private readonly visibilityChanged = (): void => {
    if (document.visibilityState === "visible") this.retry()
  }

  constructor(private readonly host: BankRefreshHost) {}

  start(): void {
    window.addEventListener("online", this.retry)
    document.addEventListener("visibilitychange", this.visibilityChanged)
  }

  stop(): void {
    window.removeEventListener("online", this.retry)
    document.removeEventListener("visibilitychange", this.visibilityChanged)
  }

  async refresh(): Promise<void> {
    this.retryOwed = false
    const generation = this.host.current().bankGeneration
    const fresh = await fetchBank({ url: this.host.bankUrl })
    if (this.host.disposed()) return
    if (!fresh) {
      this.retryOwed = true
      return
    }
    const before = this.host.current()
    const after = this.host.apply((s) => bankFetched(s, fresh.bank, generation, fresh.held))
    dispatchGameble("gameble:booster-changed", null)
    if (after !== before) reservesUnlocked(before.bank, after.bank).forEach((reserve) => this.host.announce(reserve))
  }

  async dailyCollected(): Promise<void> {
    await this.refresh()
    if (!this.host.disposed()) this.host.apply(dailyCapsuleChosen)
  }

  changedElsewhere(): void {
    if (this.host.disposed() || !this.host.state()) return
    if (!bankDue(this.host.apply(bankFetchOwed))) return
    this.host.apply(owedBankTaken)
    void this.dailyCollected()
  }

  atZero(): void {
    this.whenDue()
  }

  private whenDue(): void {
    const state = this.host.state()
    if (this.host.disposed() || !state) return
    if (countdownAtZero(state) === "bank") void this.refresh()
    else this.host.apply(bankFetchOwed)
  }
}
