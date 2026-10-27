import { NARROW_QUERY, PHONE_QUERY, layoutAsked, layoutFor } from "./booster"
import type { Transition } from "./booster_host"

export type LayoutWatchHost = Readonly<{
  apply: (transition: Transition) => unknown
  whenIdle: () => void
}>

export class LayoutWatch {
  private media: { phone: MediaQueryList; narrow: MediaQueryList } | null = null

  constructor(private readonly host: LayoutWatchHost) {}

  start(): void {
    if (typeof window.matchMedia !== "function") return
    this.media = { phone: window.matchMedia(PHONE_QUERY), narrow: window.matchMedia(NARROW_QUERY) }
    this.media.phone.addEventListener("change", this.changed)
    this.media.narrow.addEventListener("change", this.changed)
    this.changed()
  }

  stop(): void {
    this.media?.phone.removeEventListener("change", this.changed)
    this.media?.narrow.removeEventListener("change", this.changed)
    this.media = null
  }

  private readonly changed = (): void => {
    const media = this.media
    if (!media) return
    this.host.apply((s) => layoutAsked(s, layoutFor(media.phone.matches, media.narrow.matches)))
    this.host.whenIdle()
  }
}
