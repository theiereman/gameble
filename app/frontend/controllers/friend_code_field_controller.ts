import { Controller } from "@hotwired/stimulus"
import { formatFriendCode } from "../lib/friend_code"

export default class extends Controller<HTMLInputElement> {
  format(event: Event): void {
    const field = this.element
    if ((event as InputEvent).isComposing) return

    const deleting = (event as InputEvent).inputType?.startsWith("delete") ?? false
    const { value, caret } = formatFriendCode(field.value, field.selectionStart ?? field.value.length, deleting)
    if (value === field.value) return

    field.value = value
    field.setSelectionRange(caret, caret)
  }
}
