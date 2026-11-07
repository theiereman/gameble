import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent<HTMLButtonElement> {
  static component = "share"
  static values = { url: String, text: String }

  declare readonly urlValue: string
  declare readonly textValue: string

  connect(): void {
    super.connect()
    this.element.hidden = false
  }

  share(): void {
    this.send("share", { url: this.urlValue, text: this.textValue })
  }
}
