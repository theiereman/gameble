import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "sheet"

  close(event: Event): void {
    if (!this.enabled) return
    event.preventDefault()
    this.send("close")
  }
}
