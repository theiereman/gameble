import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"

// A button that opens a modal dialog of the page, named by its id
// (ButtonComponent's `opens:`, FriendsHelper#dialog_opener_attributes). The dialog is shown as a
// modal and remembers this button, which gets the focus back when it closes
// (dialog_controller.ts); a button inside a popover menu hands that focus to
// the button that opens the menu, since the modal closes the menu. An unknown
// id does nothing.
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
