import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"
import { STEPPER, keepStepperFocus, quantityFromButton, quantityFromKey, reflectStepper, type StepperView } from "../lib/stepper"
import { cloneContent } from "../lib/templates"
import type { Side } from "../lib/trade_board"

export type LineView = { key: string; quantity: number; removeLabel: string; stepper: StepperView | null }

export type SideView = { lines: readonly LineView[]; count: string; canAdd: boolean; help: boolean }

export type FaceFor = (key: string) => DocumentFragment | null

export type SideIntent = { side: Side; key: string }

const PENDING_FACE = "trade-card__face--pending"

export default class TradeBoardSideController extends Controller<HTMLElement> {
  static targets = ["list", "addSlot", "add", "count", "help", "lineTemplate"]

  declare readonly listTarget: HTMLUListElement
  declare readonly addSlotTarget: HTMLLIElement
  declare readonly addTarget: HTMLButtonElement
  declare readonly countTarget: HTMLElement
  declare readonly hasHelpTarget: boolean
  declare readonly helpTarget: HTMLElement
  declare readonly lineTemplateTarget: HTMLTemplateElement

  get side(): Side {
    return this.element.dataset.side === "own" ? "own" : "friend"
  }

  render({ lines, count, canAdd, help }: SideView, faceFor: FaceFor): void {
    const wanted = new Set(lines.map((line) => line.key))
    for (const item of this.items()) if (!wanted.has(item.dataset.key ?? "")) item.remove()

    const items = new Map(this.items().map((item) => [item.dataset.key ?? "", item]))
    lines.forEach((line, at) => {
      let item = items.get(line.key)
      if (item && (item.querySelector(STEPPER) !== null) !== (line.stepper !== null)) {
        item.remove()
        item = undefined
      }
      item ??= this.newLine(line.stepper !== null)
      this.fill(item, line, faceFor)
      const current = this.listTarget.children[at]
      if (current !== item) this.listTarget.insertBefore(item, current ?? this.addSlotTarget)
    })

    this.addSlotTarget.hidden = !canAdd
    writeText(this.countTarget, count)
    if (this.hasHelpTarget) this.helpTarget.hidden = !help
  }

  focus(key: string | null, preventScroll = false): void {
    const remove = key === null ? null : this.listTarget.querySelector<HTMLElement>(`[data-remove="${CSS.escape(key)}"]`)
    const fallback = this.addSlotTarget.hidden ? this.listTarget.querySelector<HTMLElement>(".trade-card__remove") : this.addTarget
    ;(remove ?? fallback)?.focus({ preventScroll })
  }

  add(): void {
    this.dispatch("add", { detail: { side: this.side } })
  }

  remove(event: Event): void {
    const key = this.keyOf(event)
    if (key) this.dispatch("remove", { detail: { side: this.side, key } satisfies SideIntent })
  }

  stepperKey(event: KeyboardEvent): void {
    this.report(event, quantityFromKey(event))
  }

  step(event: Event): void {
    this.report(event, quantityFromButton(event))
  }

  keepFocus(event: Event): void {
    keepStepperFocus(event)
  }

  private report(event: Event, quantity: number | null): void {
    const key = this.keyOf(event)
    if (key && quantity !== null) this.dispatch("quantity", { detail: { side: this.side, key, quantity } })
  }

  private keyOf(event: Event): string | undefined {
    return (event.currentTarget as Element).closest<HTMLElement>("[data-key]")?.dataset.key
  }

  private items(): HTMLLIElement[] {
    return Array.from(this.listTarget.querySelectorAll<HTMLLIElement>(":scope > li[data-key]"))
  }

  private newLine(withStepper: boolean): HTMLLIElement {
    const fragment = cloneContent(this.lineTemplateTarget)
    const item = fragment.querySelector<HTMLLIElement>("li")!
    if (!withStepper) item.querySelector(STEPPER)?.remove()
    return item
  }

  private fill(item: HTMLLIElement, { key, quantity, removeLabel, stepper }: LineView, faceFor: FaceFor): void {
    item.dataset.key = key
    item.classList.toggle("trade-card--stack", quantity > 1)

    const face = item.querySelector<HTMLElement>(`.${PENDING_FACE}`)
    const content = face && faceFor(key)
    if (face && content) {
      face.replaceChildren(content)
      face.classList.remove(PENDING_FACE)
    }

    const spinner = item.querySelector<HTMLElement>(STEPPER)
    if (spinner && stepper) reflectStepper(spinner, stepper)

    const remove = item.querySelector<HTMLElement>(".trade-card__remove")
    if (remove) {
      remove.dataset.remove = key
      remove.setAttribute("aria-label", removeLabel)
    }

    const field = item.querySelector<HTMLInputElement>("input[type=hidden]")
    if (field) {
      field.name = `${this.element.dataset.field}[${key}]`
      field.value = String(quantity)
    }
  }
}
