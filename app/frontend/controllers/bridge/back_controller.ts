import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "back"
  static targets = ["label"]

  declare readonly labelTarget: HTMLElement

  connect(): void {
    super.connect()
    this.send("connect", {}, ({ data }) => {
      if (typeof data.previousLabel === "string" && data.previousLabel !== "") {
        this.labelTarget.textContent = data.previousLabel
      }
      this.element.hidden = data.canGoBack !== true
    })
  }

  back(): void {
    this.send("back")
  }
}
