import { Controller } from "@hotwired/stimulus"
import type { Layout, OpenVariant } from "../lib/booster"
import { writeFlag, writeText } from "../lib/dom_writes"

export type ActionsView = Readonly<{
  open: OpenVariant
  openDisabled: boolean
  busy: boolean
  revealAllDisabled: boolean
  locked: boolean
  reason: string | null
}>

export default class BoosterActionsController extends Controller<HTMLElement> {
  static targets = ["open", "row", "revealAll", "back", "reason"]

  declare readonly openTarget: HTMLButtonElement
  declare readonly rowTarget: HTMLElement
  declare readonly revealAllTarget: HTMLButtonElement
  declare readonly backTarget: HTMLAnchorElement
  declare readonly reasonTarget: HTMLElement

  private busy = false

  get openButton(): HTMLButtonElement {
    return this.openTarget
  }

  get backLink(): HTMLAnchorElement {
    return this.backTarget
  }

  render({ open, openDisabled, busy, revealAllDisabled, locked, reason }: ActionsView): void {
    this.busy = busy
    this.openTarget.dataset.open = open
    this.openTarget.disabled = openDisabled
    writeFlag(this.openTarget, "aria-disabled", !openDisabled && busy)
    this.revealAllTarget.disabled = revealAllDisabled
    writeFlag(this.backTarget, "aria-disabled", locked)
    this.reasonTarget.hidden = reason === null
    writeText(this.reasonTarget, reason ?? "")
  }

  arrange(layout: Layout): void {
    const phone = layout === "phone"
    const order = phone ? [this.rowTarget, this.backTarget, this.reasonTarget] : [this.openTarget, this.rowTarget, this.reasonTarget]
    const row = phone ? [this.openTarget, this.revealAllTarget] : [this.revealAllTarget, this.backTarget]
    if (this.inOrder(this.element, order) && this.inOrder(this.rowTarget, row)) return
    this.rowTarget.replaceChildren(...row)
    this.element.replaceChildren(...order)
  }

  open(): void {
    if (!this.busy) this.dispatch("open")
  }

  revealAll(): void {
    this.dispatch("reveal")
  }

  back(event: Event): void {
    const asked = this.dispatch("back")
    if (asked.defaultPrevented) event.preventDefault()
  }

  private inOrder(parent: Element, children: readonly Element[]): boolean {
    return parent.children.length === children.length && children.every((child, index) => parent.children[index] === child)
  }
}
