import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

import { onGameble } from "../../lib/events"

export default class extends BridgeComponent {
  static component = "pull-to-refresh"

  private heldTouches = 0
  private stopListening?: () => void

  connect(): void {
    super.connect()
    this.stopListening = onGameble("gameble:touch-held", ({ held }) => (held ? this.hold() : this.letGo()))
  }

  disconnect(): void {
    this.stopListening?.()
    if (this.heldTouches > 0) this.send("release")
    this.heldTouches = 0
    super.disconnect()
  }

  private hold(): void {
    this.heldTouches += 1
    if (this.heldTouches === 1) this.send("hold")
  }

  private letGo(): void {
    if (this.heldTouches === 0) return
    this.heldTouches -= 1
    if (this.heldTouches === 0) this.send("release")
  }
}
