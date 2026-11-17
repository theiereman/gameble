import { Controller } from "@hotwired/stimulus"
import {
  acceptsView,
  boardShown,
  choose,
  cleared,
  drawnCards,
  GUARD_MS,
  handShown,
  moveNumberFrom,
  ready,
  released,
  revealDismissed,
  revealSeen,
  startDuel,
  viewShown,
  withReadiness,
  type DuelState,
  type Field,
} from "../lib/duel"
import { focusTarget, handCards, renderChoices, submitButton } from "../lib/duel_form"

type StreamElement = Element & { templateContent?: DocumentFragment }

const FIELDS: readonly string[] = ["card", "stat", "direction"]

export default class extends Controller<HTMLElement> {
  static targets = ["board", "live", "reveal", "form", "status"]

  declare readonly boardTarget: HTMLElement
  declare readonly liveTarget: HTMLElement
  declare readonly revealTarget: HTMLElement
  declare readonly formTarget: HTMLFormElement
  declare readonly statusTarget: HTMLElement
  declare readonly hasBoardTarget: boolean
  declare readonly hasRevealTarget: boolean
  declare readonly hasFormTarget: boolean
  declare readonly hasStatusTarget: boolean

  private state?: DuelState
  private armTimer?: number
  private revealTimer?: number

  connect(): void {
    document.addEventListener("turbo:before-stream-render", this.streamed)
    document.addEventListener("keydown", this.escaped)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
    document.removeEventListener("keydown", this.escaped)
    window.clearTimeout(this.armTimer)
    window.clearTimeout(this.revealTimer)
  }

  boardTargetConnected(board: HTMLElement): void {
    const moveNumber = moveNumberFrom(board.dataset.moveNumber)
    if (moveNumber === null) return

    const first = this.state === undefined
    const now = performance.now()
    let state = boardShown(this.state ?? startDuel(moveNumber), moveNumber)
    state = revealSeen(state, this.revealRound(), now)

    const hand = handCards(board)
    const cards = hand.map((card) => card.dataset.card ?? "")
    drawnCards(state, cards).forEach((token) =>
      hand.find((card) => card.dataset.card === token)?.setAttribute("data-drawn", ""),
    )
    this.state = handShown(state, cards)

    if (!first && board.dataset.announce && this.hasStatusTarget) this.statusTarget.textContent = board.dataset.announce
    this.showBoard()
  }

  choose(event: Event): void {
    const radio = event.target as HTMLInputElement
    if (!this.state || !FIELDS.includes(radio.name)) return

    const blocked = radio.getAttribute("aria-disabled") === "true"
    this.state = choose(this.state, radio.name as Field, radio.value, blocked)
    this.refresh()
  }

  press(event: Event): void {
    const button = this.guardedButton(event)
    if (!button) return

    event.preventDefault()
    this.release(button)
  }

  keydown(event: KeyboardEvent): void {
    if (event.key === "Enter") event.preventDefault()
  }

  keyup(event: KeyboardEvent): void {
    const button = this.guardedButton(event)
    if (button && event.key === "Enter") this.release(button)
  }

  next(event: Event): void {
    if ((event.target as Element).closest("button")) this.dismissReveal()
  }

  private readonly streamed = (event: Event): void => {
    const stream = event.target as StreamElement
    if (stream.getAttribute("target") !== "duel-board") return

    const moveNumber = moveNumberFrom(stream.templateContent?.firstElementChild?.getAttribute("data-move-number"))
    if (moveNumber === null || (this.state && !acceptsView(this.state, moveNumber))) return event.preventDefault()

    this.state = this.state ? viewShown(this.state, moveNumber) : startDuel(moveNumber)
  }

  private readonly escaped = (event: KeyboardEvent): void => {
    if (event.key !== "Escape" || event.defaultPrevented || !this.state || document.querySelector("dialog[open]"))
      return

    const next = cleared(this.state)
    if (next === this.state) return

    event.preventDefault()
    this.state = next
    this.refresh()
  }

  private guardedButton(event: Event): HTMLElement | null {
    return (event.target as Element).closest<HTMLElement>("button[type=submit]")
  }

  private release(button: HTMLElement): void {
    if (!this.state || button.getAttribute("aria-disabled") === "true" || !released(this.state, performance.now()))
      return

    this.state = withReadiness(this.state, false, performance.now())
    button.setAttribute("aria-disabled", "true")
    button.removeAttribute("data-armed")
    this.formTarget.requestSubmit()
  }

  private revealRound(): number | null {
    return this.hasRevealTarget ? moveNumberFrom(this.revealTarget.dataset.round) : null
  }

  private showBoard(): void {
    const state = this.state
    if (!state) return

    const reveal = state.reveal
    if (this.hasRevealTarget) this.revealTarget.hidden = reveal === null
    this.liveTarget.hidden = reveal !== null
    window.clearTimeout(this.revealTimer)
    if (reveal)
      this.revealTimer = window.setTimeout(() => this.dismissReveal(), Math.max(0, reveal.endsAt - performance.now()))

    this.refresh()
    // Turbo puts the focus back on the element it held before a stream render once the render is done: move it after.
    window.setTimeout(() => this.hasBoardTarget && focusTarget(this.boardTarget)?.focus(), 0)
  }

  private dismissReveal(): void {
    if (!this.state) return

    this.state = revealDismissed(this.state)
    this.showBoard()
  }

  private refresh(): void {
    if (!this.state || !this.hasFormTarget) return

    const form = this.formTarget
    renderChoices(form, this.state)
    const before = this.state.activeSince
    this.state = withReadiness(
      this.state,
      !this.liveTarget.hidden && ready(this.state, form.dataset.duelKind === "call" ? "call" : "answer"),
      performance.now(),
    )

    const button = submitButton(form)
    if (!button) return
    button.setAttribute("aria-disabled", String(this.state.activeSince === null))
    if (this.state.activeSince === before) return

    window.clearTimeout(this.armTimer)
    button.removeAttribute("data-armed")
    if (this.state.activeSince !== null)
      this.armTimer = window.setTimeout(() => button.setAttribute("data-armed", ""), GUARD_MS)
  }
}
