import { Controller } from "@hotwired/stimulus"
import { LIVE_DELAY, edit, parse, posted, retermed, start, submit, submitted, type AnnonceState } from "../lib/annonce"
import { ask, consented, gate, grant, multipleOf } from "../lib/annonce_confirm"
import { readLine, readOutcome } from "../lib/annonce_status"
import { dispatchGameble } from "../lib/events"
import { picoins } from "../lib/picoins"
import { footViewOf, type AnnonceStrings, type Forms } from "../lib/annonce_view"
import type { Intent } from "../lib/screen"
import type AnnonceDialogController from "./annonce_dialog_controller"
import type AnnonceFieldController from "./annonce_field_controller"
import type AnnonceFootController from "./annonce_foot_controller"
import type AnnonceStatusController from "./annonce_status_controller"

const END_REFRESH_DELAY = 500

export default class AnnonceController extends Controller<HTMLElement> {
  static targets = ["region", "notRecorded"]
  static values = { locale: String, strings: Object }
  static outlets = ["annonce-field", "annonce-foot", "annonce-status", "annonce-dialog"]

  declare readonly regionTarget: HTMLElement
  declare readonly hasNotRecordedTarget: boolean
  declare readonly notRecordedTarget: HTMLTemplateElement
  declare readonly localeValue: string
  declare readonly stringsValue: AnnonceStrings
  declare readonly hasAnnonceFieldOutlet: boolean
  declare readonly annonceFieldOutlet: AnnonceFieldController
  declare readonly hasAnnonceFootOutlet: boolean
  declare readonly annonceFootOutlet: AnnonceFootController
  declare readonly hasAnnonceStatusOutlet: boolean
  declare readonly annonceStatusOutlet: AnnonceStatusController
  declare readonly annonceDialogOutlets: AnnonceDialogController[]

  private state?: AnnonceState
  private timer?: ReturnType<typeof setTimeout>
  private asked?: HTMLElement | null
  private interrupted: { notRecorded: boolean } | null = null

  disconnect(): void {
    clearTimeout(this.timer)
    this.state = undefined
  }

  annonceFieldOutletConnected(field: AnnonceFieldController): void {
    clearTimeout(this.timer)
    const fresh = start(field.terms(), field.answered)
    this.state = field.text ? edit(fresh, field.text) : fresh
    this.render()
  }

  annonceFieldOutletDisconnected(): void {
    clearTimeout(this.timer)
    this.state = undefined
  }

  annonceFootOutletConnected(): void {
    this.render()
  }

  annonceStatusOutletConnected(status: AnnonceStatusController): void {
    status.observe(readLine(this.element), null)
  }

  morphed(): void {
    if (this.hasAnnonceStatusOutlet) this.annonceStatusOutlet.observe(readLine(this.element), readOutcome(this.element))
    const heading = this.element.querySelector<HTMLElement>("#listing-outcome-heading")
    if (!this.interrupted || !heading) return
    heading.focus()
    if (
      this.interrupted.notRecorded &&
      this.hasNotRecordedTarget &&
      !this.regionTarget.querySelector(".market-bid__note")
    ) {
      this.regionTarget.append(this.notRecordedTarget.content.cloneNode(true))
    }
    this.interrupted = null
  }

  ended(): void {
    const field = this.hasAnnonceFieldOutlet ? this.annonceFieldOutlet : null
    const open = this.annonceDialogOutlets.some((dialog) => dialog.isOpen)
    const typed = field !== null && field.text.trim() !== ""
    if (typed || open || field?.focused) this.interrupted = { notRecorded: typed || open }
    for (const dialog of this.annonceDialogOutlets) dialog.close()
    field?.release()
    setTimeout(() => dispatchGameble("gameble:listing-updated", {}), END_REFRESH_DELAY)
  }

  regionTargetConnected(region: HTMLElement): void {
    const name = region.dataset.focus
    if (name) region.querySelector<HTMLElement>(`[data-focus-name='${name}']`)?.focus()
  }

  retermed(): void {
    if (!this.state || !this.hasAnnonceFieldOutlet) return
    const field = this.annonceFieldOutlet
    this.state = retermed(this.state, field.terms(), field.answered)
    this.render()
  }

  typed({ detail: { text } }: Intent<{ text: string }>): void {
    if (!this.state) return
    this.state = edit(this.state, text)
    this.render()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.postLive(), LIVE_DELAY)
  }

  entered(): void {
    if (this.hasAnnonceFootOutlet) this.annonceFootOutlet.focusSubmit()
  }

  raise(): void {
    if (this.hasAnnonceFieldOutlet) this.annonceFieldOutlet.focus()
  }

  submit(event: SubmitEvent): void {
    const state = this.state
    if (!state) return
    const submitter = event.submitter instanceof HTMLElement ? event.submitter : null
    if (!consented(state) && gate(state) === "unusual") {
      event.preventDefault()
      this.confirmFirst(ask(state), submitter)
      return
    }
    const next = submit(state)
    if (!next) {
      event.preventDefault()
      return
    }
    this.state = next
    if (this.hasAnnonceFieldOutlet) this.annonceFieldOutlet.unpin()
  }

  confirmed(): void {
    const state = this.state
    if (!state?.pending) return
    this.unusualDialog()?.close()
    this.state = grant(state)
    const form = this.element.querySelector<HTMLFormElement>("form#annonce-form")
    if (this.asked?.isConnected) form?.requestSubmit(this.asked)
    else form?.requestSubmit()
  }

  submitted(): void {
    if (this.hasAnnonceStatusOutlet) this.annonceStatusOutlet.own()
    if (this.state) this.state = submitted(this.state)
  }

  private confirmFirst(state: AnnonceState, submitter: HTMLElement | null): void {
    this.state = state
    this.asked = submitter
    const dialog = this.unusualDialog()
    if (!dialog || !this.hasAnnonceFieldOutlet) return
    const amount = parse(state.text) ?? 0
    const texts = {
      amount: picoins(amount, { locale: this.localeValue }),
      multiple: String(multipleOf(amount, state.terms.price)),
    }
    dialog.open(this.annonceFieldOutlet.input, texts)
  }

  private unusualDialog(): AnnonceDialogController | undefined {
    return this.annonceDialogOutlets.find((dialog) => dialog.kind === "unusual")
  }

  private forms(): Forms {
    return { locale: this.localeValue, strings: this.stringsValue }
  }

  private render(): void {
    if (this.state && this.hasAnnonceFootOutlet) this.annonceFootOutlet.render(footViewOf(this.state, this.forms()))
  }

  private postLive(): void {
    if (!this.state || !this.hasAnnonceStatusOutlet) return
    const { live } = footViewOf(this.state, this.forms())
    if (live === "" || live === this.state.posted) return
    this.annonceStatusOutlet.say(live)
    this.state = posted(this.state, live)
  }
}
