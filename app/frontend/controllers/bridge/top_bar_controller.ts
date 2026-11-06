import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { fetchChip } from "../../lib/countdown"
import { dispatchGameble, onGameble } from "../../lib/events"

export default class extends BridgeComponent {
  static component = "top-bar"
  static values = { url: String }

  declare readonly urlValue: string

  private stopListening?: () => void

  connect(): void {
    super.connect()
    this.stopListening?.()
    this.stopListening = onGameble("gameble:screen-shown", () => void this.refresh())
    document.addEventListener("visibilitychange", this.cameBack)
  }

  disconnect(): void {
    this.stopListening?.()
    this.stopListening = undefined
    document.removeEventListener("visibilitychange", this.cameBack)
    super.disconnect()
  }

  navigate(event: Event): void {
    const link = (event.target as Element).closest<HTMLAnchorElement>("a[href]")
    if (!link || link.origin !== window.location.origin) return
    event.preventDefault()
    if (link.getAttribute("aria-disabled") === "true") return
    this.element.querySelectorAll<HTMLElement>("[popover]:popover-open").forEach((menu) => menu.hidePopover())
    this.send("navigate", { path: `${link.pathname}${link.search}${link.hash}` })
  }

  private readonly cameBack = (): void => {
    if (document.visibilityState === "visible") dispatchGameble("gameble:screen-shown", null)
  }

  private async refresh(): Promise<void> {
    dispatchGameble("gameble:bank-updated", {})
    const refresh = await fetchChip(this.urlValue)
    if (refresh.kind === "render") window.Turbo.renderStreamMessage(refresh.html)
  }
}
