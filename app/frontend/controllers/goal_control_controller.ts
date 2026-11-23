import { Controller } from "@hotwired/stimulus"
import { guarded, targetsControl } from "../lib/goal_control"

type StreamRender = (stream: Element) => Promise<void> | void

export default class extends Controller<HTMLElement> {
  static values = { bought: Boolean }

  private focused = false
  private boughtAt: number | null = null

  connect(): void {
    document.addEventListener("turbo:before-stream-render", this.streamed)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
  }

  boughtValueChanged(bought: boolean): void {
    this.boughtAt = bought ? performance.now() : null
  }

  remember(event: Event): void {
    if (guarded(this.boughtAt, performance.now())) {
      event.preventDefault()
      return
    }
    this.focused = this.element.contains(document.activeElement)
  }

  // Turbo disables the pressed button while its form submits, which drops the focus, and renders the answer a repaint later.
  private readonly streamed = (event: Event): void => {
    const detail = (event as CustomEvent<{ newStream: Element; render: StreamRender }>).detail
    if (!this.focused || !this.answersPress(detail.newStream)) return
    const render = detail.render
    detail.render = async (stream) => {
      await render(stream)
      this.focusButton()
    }
  }

  private answersPress(stream: Element): boolean {
    return targetsControl(stream, this.element.id) || targetsControl(stream, "toasts")
  }

  private focusButton(): void {
    this.focused = false
    document.getElementById(this.element.id)?.querySelector<HTMLElement>(".goal-button")?.focus()
  }
}
