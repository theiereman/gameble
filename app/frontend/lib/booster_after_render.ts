import {
  celebrationSpoken,
  celebrationToAnnounce,
  focusGiven,
  focusTarget,
  type BoosterState,
  type FocusTarget,
} from "./booster"
import type { Transition } from "./booster_host"
import { celebrationAnnouncement } from "./celebration"

export type AfterRenderHost = Readonly<{
  state: () => BoosterState | undefined
  disposed: () => boolean
  apply: (transition: Transition) => unknown
  announce: (text: string) => void
  focusElement: (target: FocusTarget) => HTMLElement | null
  celebrationStrings: Parameters<typeof celebrationAnnouncement>[1]
  delimiter: string
}>

export class AfterRender {
  private queued = false

  constructor(private readonly host: AfterRenderHost) {}

  queue(): void {
    if (this.queued) return
    this.queued = true
    queueMicrotask(() => {
      this.queued = false
      if (this.host.disposed()) return
      this.giveFocus()
      this.announceCelebration()
    })
  }

  private giveFocus(): void {
    const state = this.host.state()
    const target = state && focusTarget(state)
    if (!target) return
    const element = this.host.focusElement(target)
    if (!element || (element instanceof HTMLButtonElement && element.disabled)) return
    this.host.apply(focusGiven)
    element.focus({ preventScroll: true })
  }

  private announceCelebration(): void {
    const state = this.host.state()
    const results = state && celebrationToAnnounce(state)
    if (!results || state.celebrationAnnounced) return
    this.host.apply(celebrationSpoken)
    this.host.announce(celebrationAnnouncement(results, this.host.celebrationStrings, this.host.delimiter))
  }
}
