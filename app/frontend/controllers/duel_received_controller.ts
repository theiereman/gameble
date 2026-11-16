import { Controller } from "@hotwired/stimulus"
import { isBlocked } from "../lib/duel_sheet"
import { onGameble } from "../lib/events"

export default class extends Controller<HTMLDialogElement> {
  private revealing = false
  private returnTo: HTMLElement | null = null
  private stopRevealing?: () => void

  connect(): void {
    this.returnTo = document.activeElement instanceof HTMLElement ? document.activeElement : null
    this.stopRevealing = onGameble("gameble:opening-revealing", ({ revealing }) => {
      this.revealing = revealing
      this.showWhenFree()
    })
    this.showWhenFree()
  }

  disconnect(): void {
    this.stopRevealing?.()
    this.stopRevealing = undefined
    if (this.element.open) this.element.close()
    if (this.returnTo?.isConnected) this.returnTo.focus()
  }

  keepOpen(event: Event): void {
    const { attributeName } = (event as CustomEvent<{ attributeName: string }>).detail
    if (attributeName === "open") event.preventDefault()
  }

  keepPending(event: Event): void {
    event.preventDefault()
  }

  guard(event: Event): void {
    if (isBlocked((event.target as Element).getAttribute("aria-disabled"))) event.preventDefault()
  }

  private showWhenFree(): void {
    if (this.revealing) return
    // A cached page restores the dialog open but not modal.
    if (this.element.open && !this.element.matches(":modal")) this.element.close()
    if (!this.element.open) this.element.showModal()
  }
}
