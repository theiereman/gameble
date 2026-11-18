import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["content", "button"]

  declare readonly contentTarget: HTMLElement
  declare readonly buttonTarget: HTMLButtonElement

  show(): void {
    this.buttonTarget.hidden = true
    this.contentTarget.hidden = false
    this.contentTarget.focus()
  }
}
