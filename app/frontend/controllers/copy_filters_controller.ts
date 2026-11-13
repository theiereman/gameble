import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import { writeHidden, writeText } from "../lib/dom_writes"
import { filterCount, filtering, type EntrustFilter } from "../lib/entrust"

const TYPING_PAUSE_MS = 250

// The filters of a grid of free copies: each change reloads the grid from the server through their GET form.
export default class CopyFiltersController extends Controller<HTMLElement> {
  static targets = ["search", "rarity", "doubles", "count", "number", "clear"]
  static values = { form: String }

  declare readonly searchTarget: HTMLInputElement
  declare readonly rarityTargets: HTMLInputElement[]
  declare readonly doublesTarget: HTMLInputElement
  declare readonly countTarget: HTMLElement
  declare readonly numberTarget: HTMLElement
  declare readonly clearTarget: HTMLElement
  declare readonly formValue: string

  private timer: number | undefined

  disconnect(): void {
    window.clearTimeout(this.timer)
  }

  typed(event: Event): void {
    if ((event as InputEvent).isComposing) return
    this.refresh()
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.submit(), TYPING_PAUSE_MS)
  }

  changed(): void {
    this.refresh()
    this.submit()
  }

  // Enter reloads at once; it never posts the form the field sits in.
  submitNow(event: Event): void {
    event.preventDefault()
    this.submit()
  }

  // The address follows the reloaded grid without a Turbo visit, whose view transition would swallow a click.
  reloaded(event: Event): void {
    const form = document.getElementById(this.formValue)
    const frame = event.target
    if (!(form instanceof HTMLFormElement) || !(frame instanceof HTMLElement) || frame.id !== form.dataset.turboFrame)
      return
    const src = frame.getAttribute("src")
    if (src) history.replaceState(history.state, "", src)
  }

  clear(): void {
    this.searchTarget.value = ""
    for (const box of [...this.rarityTargets, this.doublesTarget]) box.checked = false
    this.refresh()
    this.submit()
    this.searchTarget.focus()
  }

  private filter(): EntrustFilter {
    return {
      query: this.searchTarget.value,
      rarities: this.rarityTargets.filter((box) => box.checked).map((box) => box.value as Rarity),
      doubles: this.doublesTarget.checked,
    }
  }

  private refresh(): void {
    const filter = this.filter()
    const count = filterCount(filter)
    writeHidden(this.countTarget, count === 0)
    writeText(this.numberTarget, String(count))
    writeHidden(this.clearTarget, !filtering(filter))
  }

  private submit(): void {
    window.clearTimeout(this.timer)
    const form = document.getElementById(this.formValue)
    if (form instanceof HTMLFormElement) form.requestSubmit()
  }
}
