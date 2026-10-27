import { Controller } from "@hotwired/stimulus"
import type { Rarity } from "../lib/card_types"
import { writeText } from "../lib/dom_writes"
import {
  STEPPER,
  keepStepperFocus,
  quantityFromButton,
  quantityFromKey,
  reflectStepper,
  type StepperView,
} from "../lib/stepper"
import { columnsOf, type Chip, type EmptyReason, type Side, type SideFilter } from "../lib/trade_board"
import { cloneContent } from "../lib/templates"
import type { FaceFor } from "./trade_board_side_controller"

export type PickView = {
  key: string
  pressed: boolean
  disabled: boolean
  tabbable: boolean
  stepper: StepperView | null
}

export type PickerScreen = {
  side: Side
  picks: readonly PickView[]
  hasMore: boolean
  hasCards: boolean
  empty: EmptyReason | null
  results: string
  count: string
  refused: boolean
  filter: SideFilter
  folded: boolean
  chipsOn: number
  filtering: boolean
}

export type MoveIntent = { key: string; columns: number }

const PENDING_FACE = "trade-pick__face--pending"
const TOGGLE = ".trade-pick__toggle"

export default class TradeBoardPickerController extends Controller<HTMLDialogElement> {
  static targets = [
    "pick",
    "grid",
    "stash",
    "body",
    "more",
    "filters",
    "search",
    "rarity",
    "chip",
    "fold",
    "groups",
    "filterCount",
    "chipCount",
    "results",
    "clear",
    "empty",
    "refusal",
    "count",
    "place",
    "stepperTemplate",
  ]

  declare readonly pickTargets: HTMLLIElement[]
  declare readonly gridTarget: HTMLUListElement
  declare readonly stashTarget: HTMLUListElement
  declare readonly bodyTarget: HTMLElement
  declare readonly moreTarget: HTMLElement
  declare readonly filtersTarget: HTMLElement
  declare readonly searchTarget: HTMLInputElement
  declare readonly rarityTargets: HTMLInputElement[]
  declare readonly chipTargets: HTMLInputElement[]
  declare readonly foldTarget: HTMLButtonElement
  declare readonly groupsTarget: HTMLElement
  declare readonly filterCountTarget: HTMLElement
  declare readonly chipCountTarget: HTMLElement
  declare readonly resultsTarget: HTMLElement
  declare readonly clearTarget: HTMLElement
  declare readonly emptyTargets: HTMLElement[]
  declare readonly refusalTarget: HTMLElement
  declare readonly countTarget: HTMLElement
  declare readonly placeTarget: HTMLButtonElement
  declare readonly stepperTemplateTarget: HTMLTemplateElement

  private observer?: IntersectionObserver
  private observedShown = 0

  connect(): void {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.dispatch("more")
      },
      { root: this.bodyTarget, rootMargin: "0px 0px 100% 0px" },
    )
  }

  disconnect(): void {
    this.observer?.disconnect()
    this.observer = undefined
    if (this.element.open) this.element.close()
  }

  render(view: PickerScreen | null, faceFor: FaceFor): void {
    if (!view) {
      this.hide()
      return
    }
    this.element.dataset.side = view.side
    this.reflectFilters(view)
    this.reflectPicks(view, faceFor)
    for (const empty of this.emptyTargets) empty.hidden = empty.dataset.reason !== view.empty
    this.refusalTarget.hidden = !view.refused
    writeText(this.countTarget, view.count)
    if (!this.element.open) {
      this.element.showModal()
      this.scrollToTop()
    }
    this.watchMore(view)
  }

  focusActive(): void {
    const active = this.gridTarget.querySelector<HTMLElement>(`${TOGGLE}[tabindex="0"]`)
    ;(active ?? this.placeTarget).focus()
  }

  focusSearch(): void {
    this.searchTarget.focus()
  }

  scrollToTop(): void {
    this.bodyTarget.scrollTop = 0
  }

  toggle(event: Event): void {
    const key = this.keyOf(event)
    if (key) this.dispatch("toggle", { detail: { key } })
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

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof Element) || !event.target.matches(TOGGLE)) return
    const tops = Array.from(this.gridTarget.children, (item) => (item as HTMLElement).offsetTop)
    const detail: MoveIntent = { key: event.key, columns: columnsOf(tops) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  filter(): void {
    const side = this.element.dataset.side
    const filter: SideFilter = {
      query: this.searchTarget.value,
      rarities: this.rarityTargets.filter((box) => box.checked).map((box) => box.value as Rarity),
      chips: this.chipTargets.filter((box) => box.checked && box.dataset.for === side).map((box) => box.value as Chip),
    }
    this.dispatch("filter", { detail: filter })
  }

  fold(): void {
    this.dispatch("fold")
  }

  clear(): void {
    this.dispatch("clear")
  }

  place(): void {
    this.dispatch("place")
  }

  cancel(): void {
    if (this.element.open) this.element.close()
  }

  backdrop(event: MouseEvent): void {
    if (event.target === this.element) this.cancel()
  }

  closed(): void {
    this.dispatch("close")
  }

  private hide(): void {
    this.observer?.disconnect()
    this.observedShown = 0
    if (this.searchTarget.value !== "") this.searchTarget.value = ""
    if (this.element.open) this.element.close()
  }

  private reflectFilters({ side, hasCards, filter, folded, chipsOn, filtering, results }: PickerScreen): void {
    this.filtersTarget.hidden = !hasCards
    if (this.searchTarget.value !== filter.query) this.searchTarget.value = filter.query
    for (const box of this.rarityTargets) box.checked = filter.rarities.includes(box.value as Rarity)
    for (const box of this.chipTargets)
      box.checked = box.dataset.for === side && filter.chips.includes(box.value as Chip)
    this.foldTarget.setAttribute("aria-expanded", String(!folded))
    this.groupsTarget.classList.toggle("trade-picker__groups--folded", folded)
    this.filterCountTarget.hidden = chipsOn === 0
    writeText(this.chipCountTarget, String(chipsOn))
    writeText(this.resultsTarget, results)
    this.clearTarget.hidden = !filtering
  }

  private reflectPicks({ side, picks }: PickerScreen, faceFor: FaceFor): void {
    const items = new Map(
      this.pickTargets.filter((item) => item.dataset.side === side).map((item) => [item.dataset.key ?? "", item]),
    )
    const shown = new Set<Element>()
    for (const pick of picks) {
      const item = items.get(pick.key)
      if (!item) continue
      this.reflectPick(item, pick, faceFor)
      const current = this.gridTarget.children[shown.size]
      if (current !== item) this.gridTarget.insertBefore(item, current ?? null)
      shown.add(item)
    }
    for (const item of Array.from(this.gridTarget.children)) if (!shown.has(item)) this.stashTarget.append(item)
    this.gridTarget.hidden = shown.size === 0
  }

  private reflectPick(
    item: HTMLElement,
    { key, pressed, disabled, tabbable, stepper }: PickView,
    faceFor: FaceFor,
  ): void {
    item.querySelector(".trade-pick__card")?.classList.toggle("trade-pick__card--picked", pressed)
    const check = item.querySelector<HTMLElement>(".trade-pick__check")
    if (check) check.hidden = !pressed

    const toggle = item.querySelector<HTMLElement>(TOGGLE)
    if (toggle) {
      toggle.tabIndex = tabbable ? 0 : -1
      toggle.setAttribute("aria-pressed", String(pressed))
      if (disabled) toggle.setAttribute("aria-disabled", "true")
      else toggle.removeAttribute("aria-disabled")
    }

    const face = item.querySelector<HTMLElement>(`.${PENDING_FACE}`)
    const content = face && faceFor(key)
    if (face && content) {
      face.replaceChildren(content)
      face.classList.remove(PENDING_FACE)
    }

    const foot = item.querySelector<HTMLElement>(".trade-pick__foot")
    const available = foot?.querySelector<HTMLElement>(".trade-pick__available")
    let spinner = foot?.querySelector<HTMLElement>(STEPPER) ?? null
    if (stepper && foot && !spinner) {
      const fragment = cloneContent(this.stepperTemplateTarget)
      spinner = fragment.querySelector<HTMLElement>(STEPPER)
      if (spinner) foot.append(spinner)
    }
    if (stepper && spinner) reflectStepper(spinner, stepper)
    if (!stepper) spinner?.remove()
    if (available) available.hidden = stepper !== null
  }

  private watchMore({ hasMore, picks }: PickerScreen): void {
    this.moreTarget.hidden = !hasMore
    if (!hasMore || !this.observer) {
      this.observer?.disconnect()
      this.observedShown = 0
      return
    }
    if (this.observedShown === picks.length) return
    this.observedShown = picks.length
    this.observer.disconnect()
    this.observer.observe(this.moreTarget)
  }

  private report(event: Event, quantity: number | null): void {
    const key = this.keyOf(event)
    if (key && quantity !== null) this.dispatch("quantity", { detail: { key, quantity } })
  }

  private keyOf(event: Event): string | undefined {
    return (event.currentTarget as Element).closest<HTMLElement>(".trade-pick")?.dataset.key
  }
}
