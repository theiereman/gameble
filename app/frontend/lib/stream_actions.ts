import { dispatchGameble } from "./events"
import type { TurboGlobal } from "./turbo"

export const STREAM_EVENT_ACTION = "gameble-event"

export const STREAM_SIGNALS = ["trades-updated", "friends-updated"] as const

export type StreamSignal = (typeof STREAM_SIGNALS)[number]

export function streamSignal(value: string | null | undefined): StreamSignal | null {
  return STREAM_SIGNALS.find((signal) => signal === value) ?? null
}

/** `<turbo-stream action="gameble-event" event="trades-updated">` raises `gameble:trades-updated` on `target`. */
export function registerStreamActions(turbo: Pick<TurboGlobal, "StreamActions">, target: EventTarget = window): void {
  turbo.StreamActions[STREAM_EVENT_ACTION] = function (this: Element): void {
    const signal = streamSignal(this.getAttribute("event"))
    if (signal) dispatchGameble(`gameble:${signal}`, {}, target)
  }
}
