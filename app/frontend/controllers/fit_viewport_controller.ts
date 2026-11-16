import { Controller } from "@hotwired/stimulus"

/* Publishes where the element starts on the page, so CSS can size it to the room left above the tab bar. */
export default class extends Controller<HTMLElement> {
  private observer?: ResizeObserver
  private readonly measure = (): void => {
    const top = this.element.getBoundingClientRect().top + window.scrollY
    this.element.style.setProperty("--fit-top", `${Math.round(top)}px`)
  }

  connect(): void {
    this.measure()
    this.observer = new ResizeObserver(this.measure)
    this.observer.observe(document.body)
    window.addEventListener("resize", this.measure)
  }

  disconnect(): void {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.measure)
    this.element.style.removeProperty("--fit-top")
  }
}
