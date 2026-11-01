import { Controller } from "@hotwired/stimulus"

type StreamRender = (stream: Element) => Promise<void> | void

export default class extends Controller<HTMLElement> {
  private focused = false

  connect(): void {
    document.addEventListener("turbo:before-stream-render", this.streamed)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
  }

  remember(): void {
    this.focused = this.element.contains(document.activeElement)
  }

  // Turbo disables the pressed button while its form submits, which drops the focus, and renders the answer a repaint later.
  private readonly streamed = (event: Event): void => {
    if (!this.focused) return
    const detail = (event as CustomEvent<{ render: StreamRender }>).detail
    const render = detail.render
    detail.render = async (stream) => {
      await render(stream)
      this.focusButton()
    }
  }

  private focusButton(): void {
    this.focused = false
    document.getElementById(this.element.id)?.querySelector<HTMLElement>("button")?.focus()
  }
}
