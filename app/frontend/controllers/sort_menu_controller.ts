import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLDetailsElement> {
  closeOutside(event: Event): void {
    if (event.target instanceof Node && !this.element.contains(event.target)) this.element.open = false
  }

  close(): void {
    this.element.open = false
  }
}
