import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"
import { focusTarget, returnPoint, type ReturnPoint } from "../lib/purchase_dialog"

type Frame = HTMLElement & { reload(): void }

export default class extends Controller<HTMLElement> {
  static targets = ["dialog", "frame", "loading", "failed", "title", "heading"]

  declare readonly dialogTarget: HTMLDialogElement
  declare readonly hasDialogTarget: boolean
  declare readonly frameTarget: Frame
  declare readonly loadingTarget: HTMLTemplateElement
  declare readonly hasFailedTarget: boolean
  declare readonly failedTarget: HTMLTemplateElement
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

  frameTargetConnected(frame: Frame): void {
    frame.addEventListener("turbo:fetch-request-error", this.failed)
    frame.addEventListener("turbo:frame-missing", this.failed)
  }

  frameTargetDisconnected(frame: Frame): void {
    frame.removeEventListener("turbo:fetch-request-error", this.failed)
    frame.removeEventListener("turbo:frame-missing", this.failed)
  }

  retry(): void {
    this.frameTarget.replaceChildren(this.loadingTarget.content.cloneNode(true))
    this.frameTarget.reload()
  }

  titleTargetConnected(title: HTMLElement): void {
    if (this.hasDialogTarget && this.dialogTarget.open) title.focus()
  }

  private readonly failed = (event: Event): void => {
    if (!this.hasFailedTarget) return
    event.preventDefault()
    this.frameTarget.replaceChildren(this.failedTarget.content.cloneNode(true))
  }

  closed(): void {
    const { opener, point } = this
    this.opener = undefined
    this.point = undefined
    if (!opener || opener.isConnected || !point) return
    focusTarget(point, (id) => document.getElementById(id))?.focus()
  }
}
