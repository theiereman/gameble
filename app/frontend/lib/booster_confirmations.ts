import { confirmationRefused, openingConfirmed, type BoosterState, type Reserve } from "./booster"
import type { Transition } from "./booster_host"
import { csrfToken } from "./booster_page"
import { sendOpening, type OpeningAnswer } from "./opening"
import { OpeningQueue, dequeueStored, enqueueStored, type QueuedOpening, type SettledOpening } from "./opening_queue"
import type { ScreenTimers } from "./screen_timers"

export type ConfirmationsHost = Readonly<{
  openUrl: string
  current: () => BoosterState
  timers: () => ScreenTimers
  apply: (transition: Transition) => BoosterState
  announce: (text: string) => void
  keepFaces: (answer: OpeningAnswer) => void
  refreshBank: () => Promise<void>
}>

export class OpeningConfirmations {
  private readonly queue: OpeningQueue
  private readonly flush = (): void => this.queue.flush()
  private readonly visibilityChanged = (): void => {
    if (document.visibilityState === "visible") this.queue.flush()
  }

  constructor(private readonly host: ConfirmationsHost) {
    this.queue = new OpeningQueue({
      entries: () => host.current().confirming,
      send: ({ token, key, reserve }, signal) =>
        sendOpening({ url: host.openUrl, reserve, key, pack: token, signal, csrfToken: csrfToken() }),
      settle: (entry, settled) => this.settle(entry, settled),
      timers: host.timers,
    })
  }

  start(): void {
    window.addEventListener("online", this.flush)
    document.addEventListener("visibilitychange", this.visibilityChanged)
    this.queue.flush()
  }

  stop(): void {
    window.removeEventListener("online", this.flush)
    document.removeEventListener("visibilitychange", this.visibilityChanged)
  }

  confirm(entry: QueuedOpening): void {
    enqueueStored(entry)
    this.queue.flush()
  }

  awaitConfirmation(reserve: Reserve): Promise<boolean> {
    return this.queue.settled(reserve)
  }

  private settle(entry: QueuedOpening, settled: SettledOpening): void {
    dequeueStored(entry.token)
    const { host } = this
    if (host.timers().disposed) return
    if (settled.kind === "refused") {
      host.apply((s) => confirmationRefused(s, entry.token))
      host.announce(settled.message)
      void host.refreshBank()
      return
    }
    const { answer } = settled
    if (openingConfirmed(host.current(), entry.token, answer).answer === answer) host.keepFaces(answer)
    host.apply((s) => openingConfirmed(s, entry.token, answer))
  }
}
