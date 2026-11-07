import { Controller } from "@hotwired/stimulus"
import { openDialog, takeOpener } from "../lib/dialog"
import { dismisses, dragOffset, focusWrapTarget, visitLeavesPage } from "../lib/bottom_sheet"
import { dispatchGameble } from "../lib/events"
import "../lib/turbo"

const FOCUSABLE =
  "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"
const DRAG_PROPERTY = "--sheet-drag"
const OPENED_HERE = "bottomSheetOpenedHere"

type Drag = { pointerId: number; startY: number }

function isPlainClick(event: MouseEvent): boolean {
  return (
    !event.defaultPrevented && event.button === 0 && !(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
  )
}

export default class extends Controller<HTMLDialogElement> {
  static targets = ["panel", "body", "close"]

  declare readonly panelTarget: HTMLElement
  declare readonly bodyTarget: HTMLElement
  declare readonly closeTarget: HTMLButtonElement

  private drag: Drag | undefined

  private readonly closed = (): void => {
    dispatchGameble("gameble:sheet-shown", { shown: false })
    this.endDrag()
    delete this.element.dataset[OPENED_HERE]
    const opener = takeOpener(this.element)
    if (opener?.isConnected) opener.focus()
  }

  private readonly beforeCache = (): void => {
    if (visitLeavesPage(window.Turbo.navigator.currentVisit)) this.close()
  }

  connect(): void {
    this.element.addEventListener("close", this.closed)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.showSentOpenAsModal()
  }

  disconnect(): void {
    this.element.removeEventListener("close", this.closed)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.endDrag()
    if (this.element.open) {
      this.element.close()
      dispatchGameble("gameble:sheet-shown", { shown: false })
    }
    takeOpener(this.element)
  }

  openFrom(event: MouseEvent): void {
    if (!isPlainClick(event)) return
    const opener =
      event.target instanceof Element ? event.target.closest<HTMLAnchorElement>("a[data-bottom-sheet-opens]") : null
    if (!opener || opener.dataset.bottomSheetOpens !== this.element.id) return
    event.preventDefault()
    this.element.dataset[OPENED_HERE] = ""
    openDialog(this.element, opener)
    dispatchGameble("gameble:sheet-shown", { shown: true })
    this.focusFirstChoice()
  }

  close(): void {
    if (this.element.open) this.element.close()
  }

  closeOnScrim(event: MouseEvent): void {
    if (event.target === this.element) this.close()
  }

  keydown(event: KeyboardEvent): void {
    if (event.key !== "Tab") return
    const active = document.activeElement instanceof HTMLElement ? document.activeElement : null
    const target = focusWrapTarget(this.focusables(), active, event.shiftKey)
    if (!target) return
    event.preventDefault()
    target.focus()
  }

  grab(event: PointerEvent): void {
    if (event.pointerType === "mouse" || !event.isPrimary || this.drag) return
    this.drag = { pointerId: event.pointerId, startY: event.clientY }
    this.element.dataset.dragging = ""
  }

  move(event: PointerEvent): void {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    this.element.style.setProperty(DRAG_PROPERTY, `${dragOffset(this.drag.startY, event.clientY)}px`)
  }

  release(event: PointerEvent): void {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return
    const offset = dragOffset(this.drag.startY, event.clientY)
    if (dismisses(offset, this.panelTarget.getBoundingClientRect().height)) {
      this.close()
    } else {
      this.endDrag()
    }
  }

  cancelDrag(event: PointerEvent): void {
    if (this.drag && event.pointerId === this.drag.pointerId) this.endDrag()
  }

  private endDrag(): void {
    this.drag = undefined
    delete this.element.dataset.dragging
    this.element.style.removeProperty(DRAG_PROPERTY)
  }

  private focusFirstChoice(): void {
    const firstChoice = this.focusablesIn(this.bodyTarget)[0] ?? this.closeTarget
    firstChoice.focus()
  }

  private focusables(): HTMLElement[] {
    return this.focusablesIn(this.element)
  }

  private focusablesIn(root: HTMLElement): HTMLElement[] {
    return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
      (element) => element.getClientRects().length > 0,
    )
  }

  private showSentOpenAsModal(): void {
    if (this.element.matches(":modal")) return
    const openedHere = OPENED_HERE in this.element.dataset
    delete this.element.dataset[OPENED_HERE]
    if (!this.element.open) return
    this.element.close()
    if (openedHere || document.documentElement.hasAttribute("data-turbo-preview")) return
    this.element.showModal()
    dispatchGameble("gameble:sheet-shown", { shown: true })
  }
}
