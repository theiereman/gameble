import { Controller } from "@hotwired/stimulus"

export default class TradeBoardSendController extends Controller<HTMLFormElement> {
  static targets = ["reason"]

  declare readonly reasonTarget: HTMLElement

  render(blocked: boolean): void {
    const button = this.element.querySelector<HTMLButtonElement>("button[type=submit]")
    if (button) {
      button.disabled = blocked
      if (blocked) button.setAttribute("aria-describedby", this.reasonTarget.id)
      else button.removeAttribute("aria-describedby")
    }
    this.reasonTarget.hidden = !blocked
  }
}
