import { BridgeComponent, type BridgeMessage } from "@hotwired/hotwire-native-bridge"

import { pushGrant, type PushGrant } from "../../lib/native_bridge"

export default class extends BridgeComponent {
  static component = "push-permission"
  static targets = ["button", "status"]
  static values = { url: String, granted: String, denied: String, failed: String }

  declare readonly buttonTarget: HTMLButtonElement
  declare readonly statusTarget: HTMLElement
  declare readonly urlValue: string
  declare readonly grantedValue: string
  declare readonly deniedValue: string
  declare readonly failedValue: string

  connect(): void {
    super.connect()
    this.element.hidden = false
  }

  request(): void {
    this.buttonTarget.disabled = true
    this.statusTarget.textContent = ""
    this.send("request", {}, (message: BridgeMessage) => this.register(pushGrant(message.data)))
  }

  private async register(grant: PushGrant | null): Promise<void> {
    if (!grant) return this.finish(this.deniedValue)

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: this.headers(),
      body: new URLSearchParams(grant),
    }).catch(() => null)
    this.finish(response?.ok ? this.grantedValue : this.failedValue)
  }

  private finish(message: string): void {
    this.buttonTarget.disabled = false
    this.statusTarget.textContent = message
  }

  private headers(): Record<string, string> {
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
    return token ? { "X-CSRF-Token": token } : {}
  }
}
