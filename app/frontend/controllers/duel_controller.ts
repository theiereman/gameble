import { Controller } from "@hotwired/stimulus"
import { acceptsView, moveNumberFrom, startDuel, viewShown, type DuelState } from "../lib/duel"

type StreamElement = Element & { templateContent?: DocumentFragment }

export default class extends Controller<HTMLElement> {
  static targets = ["board"]

  private state?: DuelState

  connect(): void {
    document.addEventListener("turbo:before-stream-render", this.streamed)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
  }

  boardTargetConnected(board: HTMLElement): void {
    const moveNumber = moveNumberFrom(board.dataset.moveNumber)
    if (moveNumber === null) return
    this.state = this.state ? viewShown(this.state, moveNumber) : startDuel(moveNumber)
  }

  private readonly streamed = (event: Event): void => {
    const stream = event.target as StreamElement
    if (stream.getAttribute("target") !== "duel-board") return

    const moveNumber = moveNumberFrom(stream.templateContent?.firstElementChild?.getAttribute("data-move-number"))
    if (moveNumber === null || (this.state && !acceptsView(this.state, moveNumber))) return event.preventDefault()

    this.state = this.state ? viewShown(this.state, moveNumber) : startDuel(moveNumber)
  }
}
