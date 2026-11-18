import { showLatestRound, showRound } from "../lib/duel_history"
import { motionReduced } from "../lib/motion"
import { Controller } from "@hotwired/stimulus"
import {
  acceptsView,
  boardShown,
  choose,
  cleared,
  picked,
  drawnCards,
  GUARD_MS,
  handShown,
  moveNumberFrom,
  ready,
  released,
  retryOpen,
  RETRY_MS,
  revealDismissed,
  revealSeen,
  sendFailed,
  startDuel,
  viewShown,
  withReadiness,
  type DuelState,
  type Field,
} from "../lib/duel"
import { secondsUntil } from "../lib/booster_clock"
import { focusTarget, handCards, renderChoices, submitButton } from "../lib/duel_form"

type StreamElement = Element & { templateContent?: DocumentFragment }

const FIELDS: readonly string[] = ["card", "stat", "direction"]

const LEAVE_MS = 280

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
  private retryTimer?: number

  connect(): void {
    document.addEventListener("turbo:before-stream-render", this.streamed)
    document.addEventListener("keydown", this.escaped)
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-stream-render", this.streamed)
    document.removeEventListener("keydown", this.escaped)
    window.clearTimeout(this.armTimer)
    window.clearTimeout(this.revealTimer)
    window.clearTimeout(this.retryTimer)
  }

  boardTargetConnected(board: HTMLElement): void {
    const moveNumber = moveNumberFrom(board.dataset.moveNumber)
    if (moveNumber === null) return

    const first = this.state === undefined
    const now = performance.now()
    window.clearTimeout(this.retryTimer)
    let state = boardShown(this.state ?? startDuel(moveNumber), moveNumber, this.deadlineAt(board, now))
    state = revealSeen(state, this.revealRound(), now)

    const hand = handCards(board)
    const cards = hand.map((card) => card.dataset.card ?? "")
    drawnCards(state, cards).forEach((token) =>
      hand.find((card) => card.dataset.card === token)?.setAttribute("data-drawn", ""),
    )
    if (state.card === null && cards.length > 0 && this.hasFormTarget && this.formTarget.dataset.duelKind === "call")
      state = choose(state, "card", cards[0] ?? "")
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

  history(event: Event): void {
    const go = (event.target as Element).closest<HTMLElement>("[data-history-go]")?.dataset.historyGo
    if (go && this.hasBoardTarget) showRound(this.boardTarget, go)
  }

  pick(event: Event): void {
    const button = (event.target as Element).closest<HTMLElement>("[data-duel-pick]")
    const [stat, direction] = (button?.dataset.duelPick ?? "").split(":")
    if (!this.state || !stat || !direction) return

    this.state = picked(this.state, stat, direction, button?.getAttribute("aria-disabled") === "true")
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

  ended(event: Event): void {
    const { success, error, fetchResponse } = (event as CustomEvent).detail ?? {}
    if (!success && (error || (fetchResponse?.statusCode ?? 0) >= 500)) this.failed()
  }

  failed(): void {
    if (!this.state || !this.hasFormTarget) return

    this.state = sendFailed(this.state)
    const button = submitButton(this.formTarget)
    if (button && this.formTarget.dataset.duelSending) button.textContent = this.formTarget.dataset.duelSending
    window.clearTimeout(this.retryTimer)
    this.retryTimer = window.setTimeout(() => this.resend(), RETRY_MS)
  }

  next(event: Event): void {
    if ((event.target as Element).closest("button")) this.dismissReveal()
  }

  private readonly streamed = (event: Event): void => {
    const stream = event.target as StreamElement
    if (stream.getAttribute("target") === "duel-connection") return this.connectionStreamed(event, stream)
    if (stream.getAttribute("target") !== "duel-board") return

    const moveNumber = moveNumberFrom(stream.templateContent?.firstElementChild?.getAttribute("data-move-number"))
    if (moveNumber === null || (this.state && !acceptsView(this.state, moveNumber))) return event.preventDefault()

    this.state = this.state ? viewShown(this.state, moveNumber) : startDuel(moveNumber)
  }

  private connectionStreamed(event: Event, stream: StreamElement): void {
    const incoming = stream.templateContent?.firstElementChild?.getAttribute("data-away-until") ?? null
    const shown =
      document.querySelector("#duel-connection > [data-away-until]")?.getAttribute("data-away-until") ?? null
    if (incoming === shown) event.preventDefault()
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

  private resend(): void {
    if (!this.state || !this.hasFormTarget || !retryOpen(this.state, performance.now())) return

    this.retryTimer = window.setTimeout(() => this.resend(), RETRY_MS)
    const resent = this.formTarget.querySelector<HTMLInputElement>("input[name=resent]")
    if (resent) resent.value = "1"
    this.formTarget.requestSubmit()
  }

  private deadlineAt(board: HTMLElement, now: number): number | null {
    const clock = board.querySelector<HTMLElement>(".duel-clock")
    const seconds = secondsUntil(
      clock?.dataset.duelClockDeadlineValue ?? null,
      clock?.dataset.duelClockServerTimeValue ?? "",
    )
    return seconds === null ? null : now + seconds * 1000
  }

  private revealRound(): number | null {
    return this.hasRevealTarget ? moveNumberFrom(this.revealTarget.dataset.round) : null
  }

  private showBoard(): void {
    const state = this.state
    if (!state) return

    const reveal = state.reveal
    if (this.hasRevealTarget) this.revealTarget.hidden = reveal === null
    this.liveTarget.toggleAttribute("data-revealing", reveal !== null)
    window.clearTimeout(this.revealTimer)
    if (reveal)
      this.revealTimer = window.setTimeout(() => this.dismissReveal(), Math.max(0, reveal.endsAt - performance.now()))

    this.refresh()
    // Turbo puts the focus back on the element it held before a stream render once the render is done: move it after.
    window.setTimeout(() => this.hasBoardTarget && focusTarget(this.boardTarget)?.focus(), 0)
  }

  private dismissReveal(): void {
    if (!this.state) return

    const reveal = this.hasRevealTarget ? this.revealTarget : null
    if (reveal && !reveal.hidden && !reveal.hasAttribute("data-leaving") && !motionReduced()) {
      reveal.setAttribute("data-leaving", "")
      window.clearTimeout(this.revealTimer)
      this.revealTimer = window.setTimeout(() => this.settleReveal(), LEAVE_MS)
      return
    }

    this.settleReveal()
  }

  private settleReveal(): void {
    if (!this.state) return

    this.state = revealDismissed(this.state)
    if (this.hasBoardTarget) showLatestRound(this.boardTarget)
    this.showBoard()
  }

  private refresh(): void {
    if (!this.state || !this.hasFormTarget) return

    const form = this.formTarget
    renderChoices(form, this.state)
    if (this.state.sending) return

    const before = this.state.activeSince
    this.state = withReadiness(
      this.state,
      !this.liveTarget.hasAttribute("data-revealing") &&
        ready(this.state, form.dataset.duelKind === "call" ? "call" : "answer"),
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
