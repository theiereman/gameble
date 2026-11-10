import { dispatchGameble } from "./events"
import type { TurboGlobal } from "./turbo"

export const STREAM_EVENT_ACTION = "gameble-event"
export const STREAM_FOCUS_ACTION = "gameble-focus"

export const STREAM_SIGNALS = [
  "trades-updated",
  "friends-updated",
  "reactions-updated",
  "bank-updated",
  "market-updated",
  "listing-updated",
] as const

export type StreamSignal = (typeof STREAM_SIGNALS)[number]

export function streamSignal(value: string | null | undefined): StreamSignal | null {
  return STREAM_SIGNALS.find((signal) => signal === value) ?? null
}

export function registerStreamActions(turbo: Pick<TurboGlobal, "StreamActions">, target: EventTarget = window): void {
  turbo.StreamActions[STREAM_EVENT_ACTION] = function (this: Element): void {
    const signal = streamSignal(this.getAttribute("event"))
    if (signal) dispatchGameble(`gameble:${signal}`, {}, target)
  }
  turbo.StreamActions[STREAM_FOCUS_ACTION] = function (this: Element & { targetElements?: HTMLElement[] }): void {
    this.targetElements?.[0]?.focus({ preventScroll: true })
  }
}
