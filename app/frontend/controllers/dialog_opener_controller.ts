import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"

// A button that opens a modal dialog of the page, named by its id
// (ButtonComponent's `opens:`; the sign-in panel). The dialog is shown as a
// modal and remembers this button, which gets the focus back when it closes
// (dialog_controller.ts). An unknown id does nothing.
export default class extends Controller<HTMLElement> {
  static values = { dialog: String }

  declare readonly dialogValue: string

  open(event: Event): void {
    const dialog = document.getElementById(this.dialogValue)
    if (!(dialog instanceof HTMLDialogElement)) return
    event.preventDefault()
    openDialog(dialog, this.element)
  }
}
