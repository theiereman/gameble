import { Controller } from "@hotwired/stimulus"
import {
  LIVE_DELAY,
  edit,
  parse,
  posted,
  start,
  submit,
  submitted,
  type AnnonceState,
  type Submitter,
} from "../lib/annonce"
import { ask, consented, gate, grant, multipleOf } from "../lib/annonce_confirm"
import { picoins } from "../lib/picoins"
import { footViewOf, type AnnonceStrings, type Forms } from "../lib/annonce_view"
import type { Intent } from "../lib/screen"
import type AnnonceDialogController from "./annonce_dialog_controller"
import type AnnonceFieldController from "./annonce_field_controller"
import type AnnonceFootController from "./annonce_foot_controller"
import type AnnonceStatusController from "./annonce_status_controller"

export default class AnnonceController extends Controller<HTMLElement> {
  static targets = ["region"]
  static values = { locale: String, strings: Object }
  static outlets = ["annonce-field", "annonce-foot", "annonce-status", "annonce-dialog"]

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

  regionTargetConnected(region: HTMLElement): void {
    const name = region.dataset.focus
    if (name) region.querySelector<HTMLElement>(`[data-focus-name='${name}']`)?.focus()
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
    const kind: Submitter = submitter?.getAttribute("name") === "buy_now" ? "buy_now" : "bid"
    const needed = consented(state, kind) ? "none" : gate(state, kind === "buy_now")
    if (needed !== "none") {
      event.preventDefault()
      this.confirmFirst(ask(state, needed, kind), needed, submitter)
      return
    }
    const next = submit(state)
    if (!next) event.preventDefault()
    else this.state = next
  }

  confirmed(): void {
    const state = this.state
    if (!state?.pending) return
    this.dialogFor(state.pending.gate)?.close()
    this.state = grant(state)
    const form = this.element.querySelector<HTMLFormElement>("form#annonce-form")
    if (this.asked?.isConnected) form?.requestSubmit(this.asked)
    else form?.requestSubmit()
  }

  submitted(): void {
    if (this.state) this.state = submitted(this.state)
  }

  private confirmFirst(state: AnnonceState, needed: "unusual" | "buy_now", submitter: HTMLElement | null): void {
    this.state = state
    this.asked = submitter
    const dialog = this.dialogFor(needed)
    if (!dialog) return
    if (needed === "buy_now") {
      const opener = submitter ?? (this.hasAnnonceFootOutlet ? this.annonceFootOutlet.button : null)
      if (opener) dialog.open(opener)
    } else if (this.hasAnnonceFieldOutlet) {
      const amount = parse(state.text) ?? 0
      const texts = {
        amount: picoins(amount, { locale: this.localeValue }),
        multiple: String(multipleOf(amount, state.terms.price)),
      }
      dialog.open(this.annonceFieldOutlet.input, texts)
    }
  }

  private dialogFor(kind: "unusual" | "buy_now"): AnnonceDialogController | undefined {
    return this.annonceDialogOutlets.find((dialog) => dialog.kind === kind)
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
