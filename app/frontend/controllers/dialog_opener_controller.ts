import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"

// A button that opens a modal dialog of the page, named by its id. The dialog remembers this button and hands the focus back when it closes
// (to the button that opens the menu, when this one is inside a popover menu). An unknown id does nothing.
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
