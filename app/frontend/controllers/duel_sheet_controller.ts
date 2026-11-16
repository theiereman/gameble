import { Controller } from "@hotwired/stimulus"
import {
  challengeSent,
  focusAfter,
  friendToSelect,
  isBlocked,
  outcomeArrived,
  startSheet,
  type SheetState,
} from "../lib/duel_sheet"
import "../lib/turbo"

const SHEET_ID = "duel-sheet"
const FIRST_CHOICE = "input:not([aria-disabled=true]), button, a[href]"

export default class extends Controller<HTMLElement> {
  static targets = ["waiting", "outcome", "form"]

  declare readonly hasWaitingTarget: boolean
  declare readonly waitingTarget: HTMLElement
  declare readonly outcomeTarget: HTMLElement

  private state: SheetState = startSheet(false)

  connect(): void {
    this.state = startSheet(this.hasWaitingTarget)
    if (this.sheet?.hasAttribute("open")) window.setTimeout(() => this.focusFor(this.state), 0)
  }

  // The server's open attribute is only for a full visit: a morph keeps the sheet as the player left it.
  keepOpen(event: Event): void {
    const { attributeName } = (event as CustomEvent<{ attributeName: string }>).detail
    if ((event.target as Element).id === SHEET_ID && attributeName === "open") event.preventDefault()
  }

  opened(event: Event): void {
    const opener = event.target instanceof Element ? event.target.closest("[data-dialog-opener-dialog-value]") : null
    if (!(opener instanceof HTMLElement) || opener.dataset.dialogOpenerDialogValue !== SHEET_ID) return

    this.selectFriend(opener.closest<HTMLElement>("[data-duel-sheet-friend]")?.dataset.duelSheetFriend)
    this.focusFor(this.state)
  }

  guard(event: Event): void {
    if (isBlocked((event.target as Element).getAttribute("aria-disabled"))) event.preventDefault()
  }

  submit(event: Event): void {
    const submitter = (event as SubmitEvent).submitter
    if (isBlocked(submitter?.getAttribute("aria-disabled") ?? null)) return event.preventDefault()
    this.state = challengeSent(this.state)
  }

  outcomeTargetConnected(line: HTMLElement): void {
    this.state = outcomeArrived(this.state, line.dataset.duelSheetLanding ?? null)
    if (this.hasWaitingTarget) this.waitingTarget.hidden = true
    this.focusFor(this.state)
    if (this.state.landing) window.Turbo.visit(this.state.landing)
  }

  private get sheet(): HTMLDialogElement | null {
    return this.element.querySelector<HTMLDialogElement>(`#${SHEET_ID}`)
  }

  private selectFriend(token: string | undefined): void {
    const radios = Array.from(this.element.querySelectorAll<HTMLInputElement>("input[name=friend]"))
    const options = radios.map((radio) => ({ token: radio.value, ariaDisabled: radio.getAttribute("aria-disabled") }))
    const chosen = friendToSelect(options, token)
    if (chosen) radios.find((radio) => radio.value === chosen)!.checked = true
  }

  private focusFor(state: SheetState): void {
    const target = { choice: this.firstChoice(), waiting: this.waitingElement(), outcome: this.outcomeElement() }[
      focusAfter(state)
    ]
    target?.focus()
  }

  private firstChoice(): HTMLElement | null {
    return this.sheet?.querySelector<HTMLElement>(`.bottom-sheet__body ${FIRST_CHOICE}`) ?? null
  }

  private waitingElement(): HTMLElement | null {
    return this.hasWaitingTarget ? this.waitingTarget : null
  }

  private outcomeElement(): HTMLElement | null {
    return this.sheet?.querySelector<HTMLElement>("[data-duel-sheet-target=outcome]") ?? null
  }
}
