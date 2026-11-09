import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { url: String }

  declare readonly urlValue: string

  connect(): void {
    const url = this.urlValue
    this.element.remove()
    window.Turbo.visit(url)
  }
}
