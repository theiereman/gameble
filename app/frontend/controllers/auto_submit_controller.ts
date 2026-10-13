import { Controller } from "@hotwired/stimulus"
import { submitOnce } from "../lib/auto_submit"

export default class extends Controller<HTMLElement> {
  connect(): void {
    const form = this.element.querySelector("form")
    if (form) submitOnce(form, { preview: document.documentElement.hasAttribute("data-turbo-preview") })
  }
}
