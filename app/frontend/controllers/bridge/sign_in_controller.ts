import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "sign-in"

  connect(): void {
    super.connect()
    this.start()
  }

  start(): void {
    this.send("start")
  }
}
