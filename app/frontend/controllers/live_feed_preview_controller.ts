import { Controller } from "@hotwired/stimulus"
import { observeInView } from "../lib/in_view"
import { StreamHold } from "../lib/stream_hold"
import { beyondLimit } from "../lib/announce_batch"

type StreamRenderDetail = { render: (stream: Element) => void | Promise<void> }
type StreamElement = Element & { templateContent: DocumentFragment }

export default class extends Controller<HTMLElement> {
  static targets = ["source"]
  static values = { limit: Number }

  declare readonly sourceTarget: HTMLTemplateElement
  declare readonly hasSourceTarget: boolean
  declare readonly limitValue: number

  private hold = new StreamHold<Node>(0)
  private stopWatching?: () => void
  private subscribed = false

  connect(): void {
    this.hold = new StreamHold<Node>(this.limitValue)
    this.hold.hold("away")
    this.stopWatching = observeInView(this.element, (inView) => this.seen(inView))
    this.element.addEventListener("pointerenter", this.pointerEntered)
    this.element.addEventListener("pointerleave", this.pointerLeft)
    this.element.addEventListener("focusin", this.focusEntered)
    this.element.addEventListener("focusout", this.focusLeft)
    document.addEventListener("turbo:before-stream-render", this.streamed)
  }

  disconnect(): void {
    this.stopWatching?.()
    this.element.removeEventListener("pointerenter", this.pointerEntered)
    this.element.removeEventListener("pointerleave", this.pointerLeft)
    this.element.removeEventListener("focusin", this.focusEntered)
    this.element.removeEventListener("focusout", this.focusLeft)
    document.removeEventListener("turbo:before-stream-render", this.streamed)
  }

  private get list(): HTMLElement | null {
    return this.element.querySelector<HTMLElement>("#feed-entries")
  }

  private seen(inView: boolean): void {
    if (!inView) return this.hold.hold("away")
    this.subscribe()
    this.resume("away")
  }

  private subscribe(): void {
    if (this.subscribed || !this.hasSourceTarget) return
    this.subscribed = true
    const source = document.importNode(this.sourceTarget.content, true)
    source
      .querySelectorAll("turbo-cable-stream-source")
      .forEach((element) => element.setAttribute("data-turbo-temporary", ""))
    this.element.append(source)
  }

  private readonly pointerEntered = (event: PointerEvent): void => {
    if (event.pointerType === "mouse") this.hold.hold("pointer")
  }

  private readonly pointerLeft = (): void => this.resume("pointer")

  private readonly focusEntered = (): void => this.hold.hold("focus")

  private readonly focusLeft = (event: FocusEvent): void => {
    if (event.relatedTarget instanceof Node && this.element.contains(event.relatedTarget)) return
    this.resume("focus")
  }

  private readonly streamed = (event: Event): void => {
    const stream = event.target as StreamElement
    const list = this.list
    if (!list || stream.getAttribute("action") !== "prepend" || stream.getAttribute("target") !== list.id) return

    if (this.hold.held) {
      event.preventDefault()
      this.hold.defer(Array.from(stream.templateContent.children, (entry) => entry.cloneNode(true)))
      return
    }
    const detail = (event as CustomEvent<StreamRenderDetail>).detail
    const render = detail.render
    detail.render = async (rendered) => {
      await render(rendered)
      this.trim()
    }
  }

  private resume(reason: string): void {
    const list = this.list
    const batches = this.hold.release(reason)
    if (!list || batches.length === 0) return
    batches.forEach((batch) => list.prepend(...batch))
    this.trim()
  }

  private trim(): void {
    const list = this.list
    if (list) beyondLimit(Array.from(list.children), this.limitValue).forEach((entry) => entry.remove())
  }
}
