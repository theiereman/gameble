import { Controller } from "@hotwired/stimulus"

export default class RowFocusController extends Controller<HTMLElement> {
  static values = { landing: String }
  static targets = ["heading"]

  declare readonly landingValue: string
  declare readonly hasLandingValue: boolean
  declare readonly hasHeadingTarget: boolean
  declare readonly headingTarget: HTMLElement

  connect(): void {
    if (!this.hasLandingValue) return
    const title = this.landingValue === "" ? undefined : this.titleOf(this.landingValue)
    const target = title ?? (this.hasHeadingTarget ? this.headingTarget : undefined)
    target?.focus()
  }

  private titleOf(token: string): HTMLElement | undefined {
    const titles = Array.from(this.element.querySelectorAll<HTMLElement>("[data-row-token]"))
    return titles.find((title) => title.dataset.rowToken === token)
  }
}
