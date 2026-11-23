import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"
import { focusTarget, returnPoint, type ReturnPoint } from "../lib/purchase_dialog"

type Frame = HTMLElement & { reload(): void }

export default class extends Controller<HTMLElement> {
  static targets = ["dialog", "frame", "loading", "title", "heading"]

  declare readonly dialogTarget: HTMLDialogElement
  declare readonly hasDialogTarget: boolean
  declare readonly frameTarget: Frame
  declare readonly loadingTarget: HTMLTemplateElement
  declare readonly headingTarget: HTMLElement
  declare readonly hasHeadingTarget: boolean

  private opener?: HTMLElement
  private point?: ReturnPoint

  open(event: Event): void {
    const opener = event.currentTarget
    if (!(opener instanceof HTMLAnchorElement) || !this.hasDialogTarget) return
    event.preventDefault()
    this.opener = opener
    this.point = returnPoint(opener, this.hasHeadingTarget ? this.headingTarget : null)
    this.frameTarget.replaceChildren(this.loadingTarget.content.cloneNode(true))
    if (this.frameTarget.getAttribute("src") === opener.href) this.frameTarget.reload()
    else this.frameTarget.setAttribute("src", opener.href)
    openDialog(this.dialogTarget, opener)
  }

  titleTargetConnected(title: HTMLElement): void {
    if (this.hasDialogTarget && this.dialogTarget.open) title.focus()
  }

  closed(): void {
    const { opener, point } = this
    this.opener = undefined
    this.point = undefined
    if (!opener || opener.isConnected || !point) return
    focusTarget(point, (id) => document.getElementById(id))?.focus()
  }
}
