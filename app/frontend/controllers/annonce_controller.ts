import { Controller } from "@hotwired/stimulus"
import { LIVE_DELAY, edit, posted, start, submit, submitted, type AnnonceState } from "../lib/annonce"
import { footViewOf, type AnnonceStrings, type Forms } from "../lib/annonce_view"
import type { Intent } from "../lib/screen"
import type AnnonceFieldController from "./annonce_field_controller"
import type AnnonceFootController from "./annonce_foot_controller"
import type AnnonceStatusController from "./annonce_status_controller"

export default class AnnonceController extends Controller<HTMLElement> {
  static targets = ["region"]
  static values = { locale: String, strings: Object }
  static outlets = ["annonce-field", "annonce-foot", "annonce-status"]

  declare readonly localeValue: string
  declare readonly stringsValue: AnnonceStrings
  declare readonly hasAnnonceFieldOutlet: boolean
  declare readonly annonceFieldOutlet: AnnonceFieldController
  declare readonly hasAnnonceFootOutlet: boolean
  declare readonly annonceFootOutlet: AnnonceFootController
  declare readonly hasAnnonceStatusOutlet: boolean
  declare readonly annonceStatusOutlet: AnnonceStatusController

  private state?: AnnonceState
  private timer?: ReturnType<typeof setTimeout>

  disconnect(): void {
    clearTimeout(this.timer)
    this.state = undefined
  }

  annonceFieldOutletConnected(field: AnnonceFieldController): void {
    clearTimeout(this.timer)
    this.state = start(field.terms(), field.answered)
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

  submit(event: Event): void {
    const next = this.state && submit(this.state)
    if (!next) {
      event.preventDefault()
      return
    }
    this.state = next
  }

  submitted(): void {
    if (this.state) this.state = submitted(this.state)
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
