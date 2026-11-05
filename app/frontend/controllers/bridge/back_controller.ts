import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "back"

  connect(): void {
    super.connect()
    this.send("connect", {}, ({ data }) => {
      this.element.hidden = data.canGoBack !== true
    })
  }

  back(): void {
    this.send("back")
  }
}
