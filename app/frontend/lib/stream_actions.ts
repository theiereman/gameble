import { dispatchGameble } from "./events"
import type { TurboGlobal } from "./turbo"

export const STREAM_EVENT_ACTION = "gameble-event"
export const STREAM_FOCUS_ACTION = "gameble-focus"
export const STREAM_VISIT_ACTION = "gameble-visit"
export const STREAM_RELOAD_ACTION = "gameble-reload"

export const STREAM_SIGNALS = [
  "trades-updated",
  "friends-updated",
  "reactions-updated",
  "bank-updated",
  "market-updated",
  "listing-updated",
  "duels-updated",
] as const

export type StreamSignal = (typeof STREAM_SIGNALS)[number]

export function streamSignal(value: string | null | undefined): StreamSignal | null {
  return STREAM_SIGNALS.find((signal) => signal === value) ?? null
}

// A path of this site only: a stream asks for a visit when a redirect would be answered with a stream.
export function visitablePath(location: string | null): string | null {
  return location !== null && /^\/(?![/\\])/.test(location) ? location : null
}

export function registerStreamActions(
  turbo: Pick<TurboGlobal, "StreamActions"> & Partial<Pick<TurboGlobal, "visit">>,
  target: EventTarget = window,
): void {
  turbo.StreamActions[STREAM_EVENT_ACTION] = function (this: Element): void {
    const signal = streamSignal(this.getAttribute("event"))
    if (signal) dispatchGameble(`gameble:${signal}`, {}, target)
  }
  turbo.StreamActions[STREAM_VISIT_ACTION] = function (this: Element): void {
    const path = visitablePath(this.getAttribute("location"))
    if (path) turbo.visit?.(path)
  }
  turbo.StreamActions[STREAM_RELOAD_ACTION] = function (this: Element & { targetElements?: HTMLElement[] }): void {
    for (const frame of this.targetElements ?? []) {
      if (frame.tagName === "TURBO-FRAME") frame.setAttribute("src", window.location.href)
    }
  }
  turbo.StreamActions[STREAM_FOCUS_ACTION] = function (this: Element & { targetElements?: HTMLElement[] }): void {
    this.targetElements?.[0]?.focus({ preventScroll: true })
  }
}
