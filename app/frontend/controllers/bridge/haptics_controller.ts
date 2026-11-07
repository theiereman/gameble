import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

import { onGameble } from "../../lib/events"
import { DEAL_IMPACT, IMPACTS, TOUCH_IMPACT, type ImpactStyle } from "../../lib/native_bridge"

export default class extends BridgeComponent {
  static component = "haptics"

  private stopListening: Array<() => void> = []

  connect(): void {
    super.connect()
    this.stopListening = [
      onGameble("gameble:capsule-touched", () => this.impact(TOUCH_IMPACT)),
      onGameble("gameble:card-dealt", () => this.impact(DEAL_IMPACT)),
      onGameble("gameble:tier-revealed", ({ tier }) => this.impact(IMPACTS[tier])),
    ]
  }

  disconnect(): void {
    this.stopListening.forEach((stop) => stop())
    this.stopListening = []
    super.disconnect()
  }

  private impact(style: ImpactStyle): void {
    this.send("impact", { style })
  }
}
