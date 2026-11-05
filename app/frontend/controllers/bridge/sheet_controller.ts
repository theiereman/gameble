import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

import { onGameble } from "../../lib/events"

export default class extends BridgeComponent {
  static component = "sheet"

  private stopListening?: () => void

  connect(): void {
    super.connect()
    this.stopListening = onGameble("gameble:sheet-shown", ({ shown }) => this.send(shown ? "shown" : "hidden"))
  }

  disconnect(): void {
    this.stopListening?.()
    super.disconnect()
  }
}
