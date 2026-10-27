import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"

export default class extends Controller<HTMLElement> {
  static values = { dialog: String }

  declare readonly dialogValue: string

  open(event: Event): void {
    const dialog = document.getElementById(this.dialogValue)
    if (!(dialog instanceof HTMLDialogElement)) return
    event.preventDefault()
    openDialog(dialog, this.focusReturnTarget())
  }

  private focusReturnTarget(): HTMLElement {
    const menu = this.element.closest<HTMLElement>("[popover]")
    const menuOpener = menu?.id ? document.querySelector<HTMLElement>(`[popovertarget="${CSS.escape(menu.id)}"]`) : null
    return menuOpener ?? this.element
  }
}
