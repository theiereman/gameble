import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

import { onGameble } from "../../lib/events"
import { IMPACTS } from "../../lib/native_bridge"

export default class extends BridgeComponent {
  static component = "haptics"

  private stopListening?: () => void

  connect(): void {
    super.connect()
    this.stopListening = onGameble("gameble:tier-revealed", ({ tier }) => this.send("impact", { style: IMPACTS[tier] }))
  }

  disconnect(): void {
    this.stopListening?.()
    super.disconnect()
  }
}
