import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { cloneTemplate } from "../lib/templates"

export type CanisterParts = Readonly<{
  wrap: HTMLElement | null
  button: HTMLButtonElement | null
  move: HTMLElement | null
  body: HTMLElement | null
  capTop: HTMLElement | null
  capBottom: HTMLElement | null
  rays: HTMLElement | null
}>

export type CanisterView = Readonly<{
  away: boolean
  empty: boolean
  next: Readonly<{ clock: string; spoken: string }> | null
  label: string
  busy: boolean
  armed: boolean
  hintHidden: boolean
  facts: string
  docks: number
}>

export default class BoosterCanisterController extends Controller<HTMLElement> {
  static targets = ["empty", "emptyNext", "emptyClock", "emptySpoken", "canister", "hint", "facts"]

  declare readonly emptyTarget: HTMLElement
  declare readonly emptyNextTarget: HTMLElement
  declare readonly emptyClockTarget: HTMLElement
  declare readonly emptySpokenTarget: HTMLElement
  declare readonly canisterTarget: HTMLTemplateElement
  declare readonly hintTarget: HTMLElement
  declare readonly factsTarget: HTMLElement

  private wrap: HTMLElement | null = null
  private docks: number | null = null
  private busy = false

  connect(): void {
    if (!this.wrap?.isConnected) this.dock()
  }

  get parts(): CanisterParts {
    const wrap = this.wrap
    const part = (name: string) => wrap?.querySelector<HTMLElement>(`.booster-canister__${name}`) ?? null
    return {
      wrap,
      button: wrap?.querySelector<HTMLButtonElement>(".booster-canister") ?? null,
      move: part("move"),
      body: part("body"),
      capTop: part("cap--top"),
      capBottom: part("cap--bottom"),
      rays: part("rays"),
    }
  }

  render({ away, empty, next, label, busy, armed, hintHidden, facts, docks }: CanisterView): void {
    if (this.docks !== null && this.docks !== docks) this.dock()
    this.docks = docks
    this.busy = busy
    this.element.hidden = away
    this.emptyTarget.hidden = !empty
    this.emptyNextTarget.hidden = next === null
    if (next) {
      writeText(this.emptyClockTarget, next.clock)
      writeText(this.emptySpokenTarget, next.spoken)
    }
    this.hintTarget.hidden = empty
    this.factsTarget.hidden = empty
    this.hintTarget.toggleAttribute("data-hidden", hintHidden)
    this.factsTarget.toggleAttribute("data-hidden", hintHidden)
    writeText(this.factsTarget, facts)

    const { wrap, button } = this.parts
    if (!wrap || !button) return
    wrap.hidden = empty
    wrap.toggleAttribute("data-armed", armed)
    wrap.toggleAttribute("data-busy", busy)
    if (button.getAttribute("aria-label") !== label) button.setAttribute("aria-label", label)
    if (busy) button.setAttribute("aria-disabled", "true")
    else button.removeAttribute("aria-disabled")
  }

  activate(): void {
    if (!this.busy) this.dispatch("open")
  }

  private dock(): void {
    const fresh = cloneTemplate(this.canisterTarget)
    if (!fresh) return
    if (this.wrap?.isConnected) this.wrap.replaceWith(fresh)
    else this.canisterTarget.after(fresh)
    this.wrap = fresh
  }
}
