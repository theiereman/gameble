import { secondsUntil } from "./booster_clock"

export const AFTER_ZERO = 1000

type Timer = ReturnType<typeof setTimeout>

export type CountdownClock = {
  now: () => number
  hidden: () => boolean
  setTimeout: (action: () => void, ms: number) => Timer
  clearTimeout: (timer: Timer) => void
}

export type CountdownListener = {
  left: (seconds: number | null) => void
  zero: () => void
}

export class BoosterCountdown {
  private shown: number | null = null
  private started = false
  private target: string | null = null
  private deadline: number | null = null
  private tickTimer: Timer | undefined
  private zeroTimer: Timer | undefined

  constructor(
    private readonly clock: CountdownClock,
    private readonly listener: CountdownListener,
  ) {}

  get left(): number | null {
    return this.shown
  }

  set(nextAvailableAt: string | null, serverTime: string): void {
    const target = `${nextAvailableAt}|${serverTime}`
    if (this.started && target === this.target) return
    this.target = target
    this.stopTicking()
    const total = secondsUntil(nextAvailableAt, serverTime)
    this.show(total)
    this.started = true
    this.deadline = total === null ? null : this.clock.now() + total * 1000
    if (this.deadline !== null) this.tick()
  }

  visibilityChanged(): void {
    if (this.deadline === null) return
    if (this.clock.hidden()) this.stopTicking()
    else if (this.tickTimer === undefined) this.tick()
  }

  dispose(): void {
    this.stopTicking()
    if (this.zeroTimer !== undefined) this.clock.clearTimeout(this.zeroTimer)
    this.zeroTimer = undefined
    this.deadline = null
  }

  private tick(): void {
    this.tickTimer = undefined
    if (this.deadline === null) return
    const ms = this.deadline - this.clock.now()
    const seconds = Math.max(0, Math.ceil(ms / 1000))
    this.show(seconds)
    if (seconds > 0 && !this.clock.hidden()) this.tickTimer = this.clock.setTimeout(() => this.tick(), Math.max(16, ms - (seconds - 1) * 1000))
  }

  private stopTicking(): void {
    if (this.tickTimer !== undefined) this.clock.clearTimeout(this.tickTimer)
    this.tickTimer = undefined
  }

  private show(seconds: number | null): void {
    if (this.started && seconds === this.shown) return
    const before = this.started ? this.shown : null
    this.shown = seconds
    if (this.zeroTimer !== undefined) this.clock.clearTimeout(this.zeroTimer)
    this.zeroTimer = undefined
    if (before !== null && before > 0 && seconds === 0) {
      this.zeroTimer = this.clock.setTimeout(() => {
        this.zeroTimer = undefined
        this.listener.zero()
      }, AFTER_ZERO)
    }
    this.listener.left(seconds)
  }
}

export const browserCountdown = (listener: CountdownListener): BoosterCountdown =>
  new BoosterCountdown(
    {
      now: () => performance.now(),
      hidden: () => document.hidden,
      setTimeout: (action, ms) => setTimeout(action, ms),
      clearTimeout: (timer) => clearTimeout(timer),
    },
    listener,
  )
