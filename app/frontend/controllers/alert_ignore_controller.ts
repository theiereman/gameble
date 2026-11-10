import { Controller } from "@hotwired/stimulus"
import { ignoreAlert, isIgnored } from "../lib/alert_ignore"

export default class extends Controller<HTMLElement> {
  static values = { key: String, value: String }
  static classes = ["alerting"]
  static targets = ["alert"]

  declare readonly keyValue: string
  declare readonly valueValue: string
  declare readonly alertingClass: string
  declare readonly alertTarget: HTMLElement

  connect(): void {
    if (isIgnored(this.keyValue, this.valueValue)) this.hide()
  }

  ignore(): void {
    ignoreAlert(this.keyValue, this.valueValue)
    this.hide()
  }

  private hide(): void {
    this.element.classList.remove(this.alertingClass)
    this.alertTarget.hidden = true
  }
}
