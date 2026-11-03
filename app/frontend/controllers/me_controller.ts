import { Controller } from "@hotwired/stimulus"
import { type WornBack, wear, wornBack } from "../lib/me"
import { cloneContent } from "../lib/templates"

export default class extends Controller<HTMLElement> {
  static targets = ["preview", "back"]
  static values = { back: String }

  declare readonly previewTarget: HTMLElement
  declare readonly hasPreviewTarget: boolean
  declare readonly backTargets: HTMLTemplateElement[]
  declare readonly backValue: string

  private worn: WornBack = wornBack("")

  connect(): void {
    this.worn = wornBack(this.element.dataset.wornBack || this.backValue)
  }

  wear(event: CustomEvent): void {
    const next = wear(this.worn, event.detail)
    if (!next) return
    this.worn = next
    this.element.dataset.wornBack = next.back
    const look = this.backTargets.find((template) => template.dataset.key === next.back)
    if (look && this.hasPreviewTarget) this.previewTarget.replaceChildren(cloneContent(look))
  }
}
