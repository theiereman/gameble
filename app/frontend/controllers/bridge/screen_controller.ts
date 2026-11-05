import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "back"
  static values = { label: String }

  declare readonly labelValue: string

  connect(): void {
    super.connect()
    if (this.labelValue !== "") this.send("screen", { label: this.labelValue })
  }
}
