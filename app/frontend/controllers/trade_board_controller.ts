import { Controller } from "@hotwired/stimulus"
import type { Point } from "../lib/arc"
import type { Rarity } from "../lib/card_types"
import { openDialog } from "../lib/dialog"
import { currentIndex, currentScreenLabel, currentScreenLabels, recordEntry, sessionTrailStorage } from "../lib/history_trail"
import { t, type Template } from "../lib/i18n"
import { holdLiveRefresh } from "../lib/live_refresh_hold"
import { motionReduced } from "../lib/motion"
import { serverTemplate } from "../lib/server_html"
import type { StepperView } from "../lib/stepper"
import {
  MAX_CARDS,
  bySide,
  cardOf,
  changed,
  clearFilters,
  closePicker,
  draftSides,
  edit,
  moveActive,
  openPicker,
  pickerView,
  place,
  removeLine,
  restore,
  sendable,
  setFilter,
  setLineQuantity,
  setPickQuantity,
  showMore,
  showsOpenHelp,
  sideCount,
  start,
  toggleFold,
  togglePick,
  type BoardState,
  type Line,
  type PickerFilters,
  type BySide,
  type Side,
  type SideFilter,
  type TradeCard,
} from "../lib/trade_board"
import { forgetDraft, readDraft, saveDraft } from "../lib/trade_board_draft"
import { faceLoader, facesUrl, fetchFaces, type FaceLoader } from "../lib/trade_board_faces"
import { SWAP_BURST_AT, SWAP_CROSSFADE_MS, SWAP_MS, confettiDirections, swapKeyframes } from "../lib/trade_board_swap"
import type TradeBoardPickerController from "./trade_board_picker_controller"
import type { MoveIntent, PickView, PickerScreen } from "./trade_board_picker_controller"
import type TradeBoardSendController from "./trade_board_send_controller"
import type TradeBoardSideController from "./trade_board_side_controller"
import type { SideIntent, SideView } from "./trade_board_side_controller"

type BoardStrings = {
  cards: Template
  cardsCopies: Template
  quantityLabel: string
  valueText: string
  max: string
  maxPhone: string
  remove: string
  picked: string
  pickedCards: Template
  pickedCopies: Template
  results: Template
}

type SideFocus = { side: Side; key: string | null; preventScroll?: boolean }

type Intent<Detail> = CustomEvent<Detail>

const CONFETTI = 14
const CONFETTI_REACH = 90
const BURST_MS = 600

const opensElsewhere = (event: Event): boolean =>
  event instanceof MouseEvent && (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)

const centre = (element: Element): Point => {
  const rect = element.getBoundingClientRect()
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
}

const number = (value: string | undefined): number => Number(value ?? 0) || 0

function cardFrom(element: HTMLElement): TradeCard {
  const { key = "", title = "", rarity = "common", owned, reserved, max, copies, otherCopies } = element.dataset
  return {
    key,
    title,
    rarity: rarity as Rarity,
    owned: number(owned),
    reserved: number(reserved),
    max: number(max),
    copies: number(copies),
    otherCopies: number(otherCopies),
  }
}

export class TradeBoardController extends Controller<HTMLElement> {
  static targets = ["card", "line", "face", "heading", "editButton", "undoDialog"]
  static values = {
    editing: Boolean,
    focus: String,
    forget: String,
    draftKey: String,
    counterUrl: String,
    boardUrl: String,
    facesUrl: String,
    facesBatch: Number,
    swap: Boolean,
    strings: Object,
  }
  static outlets = ["trade-board-side", "trade-board-picker", "trade-board-send"]

  declare readonly cardTargets: HTMLElement[]
  declare readonly lineTargets: HTMLElement[]
  declare readonly faceTargets: HTMLTemplateElement[]
  declare readonly hasHeadingTarget: boolean
  declare readonly headingTarget: HTMLElement
  declare readonly editButtonTargets: HTMLElement[]
  declare readonly hasUndoDialogTarget: boolean
  declare readonly undoDialogTarget: HTMLDialogElement
  declare readonly editingValue: boolean
  declare readonly focusValue: string
  declare readonly forgetValue: string
  declare readonly draftKeyValue: string
  declare readonly counterUrlValue: string
  declare readonly boardUrlValue: string
  declare readonly facesUrlValue: string
  declare readonly facesBatchValue: number
  declare swapValue: boolean
  declare readonly stringsValue: BoardStrings
  declare readonly tradeBoardSideOutlets: TradeBoardSideController[]
  declare readonly hasTradeBoardPickerOutlet: boolean
  declare readonly tradeBoardPickerOutlet: TradeBoardPickerController
  declare readonly hasTradeBoardSendOutlet: boolean
  declare readonly tradeBoardSendOutlet: TradeBoardSendController

  private state?: BoardState
  private faces = new Map<string, HTMLTemplateElement>()
  private loader!: FaceLoader
  private swapping = false
  private animations: Animation[] = []
  private timers: number[] = []
  private effects: HTMLElement[] = []

  private readonly faceFor = (key: string): DocumentFragment | null => {
    const template = this.faces.get(key)
    return template ? (template.content.cloneNode(true) as DocumentFragment) : null
  }

  private readonly beforeCache = (): void => {
    if (this.state) this.apply(closePicker(this.state))
  }

  private readonly morphed = (): void => {
    if (!this.state) return
    this.seedFaces()
    this.loader = this.newLoader()
    this.state = this.startFromMarkup(this.state.filters)
    this.render()
    this.persist()
  }

  initialize(): void {
    this.loader = this.newLoader()
  }

  private newLoader(): FaceLoader {
    return faceLoader({
      known: this.faces,
      batch: this.facesBatchValue,
      load: (keys) => fetchFaces({ url: facesUrl(this.facesUrlValue, keys) }),
      onFaces: (arrived) => this.receiveFaces(arrived),
    })
  }

  connect(): void {
    if (this.forgetValue) forgetDraft(this.forgetValue)
    this.seedFaces()
    this.state = this.startFromMarkup()
    document.addEventListener("turbo:before-cache", this.beforeCache)
    document.addEventListener("turbo:morph", this.morphed)
    this.render()
    this.persist()
    this.focusOnArrival()
    this.playSwapOnce()
  }

  disconnect(): void {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.removeEventListener("turbo:morph", this.morphed)
    this.stopSwap()
    this.state = undefined
  }

  tradeBoardSideOutletConnected(outlet: TradeBoardSideController): void {
    if (this.state) this.renderSide(this.state, outlet)
  }

  tradeBoardPickerOutletConnected(outlet: TradeBoardPickerController): void {
    if (this.state) this.renderPicker(this.state, outlet)
  }

  tradeBoardSendOutletConnected(outlet: TradeBoardSendController): void {
    if (this.state) outlet.reflect(!sendable(this.state))
  }

  edit(event: Event): void {
    if (opensElsewhere(event) || !this.state) return
    event.preventDefault()
    this.apply(edit(this.state), () => this.focusSide({ side: "own", key: null }))
    this.replaceUrl(this.counterUrlValue)
  }

  undo(event: Event): void {
    if (opensElsewhere(event) || !this.state) return
    event.preventDefault()
    const opener = (event.target as Element | null)?.closest<HTMLElement>("a, button")
    if (changed(this.state) && this.hasUndoDialogTarget && opener) {
      openDialog(this.undoDialogTarget, opener)
      return
    }
    this.restore()
  }

  restore(): void {
    if (!this.state) return
    if (this.hasUndoDialogTarget && this.undoDialogTarget.open) this.undoDialogTarget.close()
    this.apply(restore(this.state), () => this.editButtonTargets[0]?.querySelector<HTMLElement>("a, button")?.focus())
    this.replaceUrl(this.boardUrlValue)
  }

  abandon(): void {
    if (this.draftKeyValue) forgetDraft(this.draftKeyValue)
  }

  removeLine({ detail: { side, key } }: Intent<SideIntent>): void {
    if (!this.state) return
    const lines = this.state.lines[side]
    const following = lines[lines.findIndex((line) => line.key === key) + 1]?.key ?? null
    this.apply(removeLine(this.state, side, key), () => this.focusSide({ side, key: following }))
  }

  setLineQuantity({ detail: { side, key, quantity } }: Intent<SideIntent & { quantity: number }>): void {
    if (this.state) this.apply(setLineQuantity(this.state, side, key, quantity))
  }

  openPicker({ detail: { side } }: Intent<{ side: Side }>): void {
    if (this.state) this.apply(openPicker(this.state, side), () => this.picker()?.focusActive())
  }

  togglePick({ detail: { key } }: Intent<{ key: string }>): void {
    if (this.state) this.apply(togglePick(this.state, key))
  }

  setPickQuantity({ detail: { key, quantity } }: Intent<{ key: string; quantity: number }>): void {
    if (this.state) this.apply(setPickQuantity(this.state, key, quantity))
  }

  setFilter({ detail }: Intent<SideFilter>): void {
    if (this.state) this.apply(setFilter(this.state, detail), () => this.picker()?.scrollToTop())
  }

  toggleFold(): void {
    if (this.state) this.apply(toggleFold(this.state))
  }

  clearFilters(): void {
    if (!this.state) return
    this.apply(clearFilters(this.state), () => {
      this.picker()?.scrollToTop()
      this.picker()?.focusSearch()
    })
  }

  showMore(): void {
    if (this.state) this.apply(showMore(this.state))
  }

  moveActive(event: Intent<MoveIntent>): void {
    if (!this.state) return
    const next = moveActive(this.state, event.detail.key, event.detail.columns)
    if (next === this.state) return
    event.preventDefault()
    this.apply(next, () => this.picker()?.focusActive())
  }

  place(): void {
    const side = this.state?.picker?.side
    if (this.state && side) this.apply(place(this.state), () => this.focusSide({ side, key: null }))
  }

  closePicker(): void {
    const side = this.state?.picker?.side
    if (this.state && side) this.apply(closePicker(this.state), () => this.focusSide({ side, key: null }))
  }

  private apply(next: BoardState, then?: () => void): void {
    if (next === this.state) return
    this.state = next
    this.render()
    then?.()
    this.persist()
  }

  private startFromMarkup(filters?: BySide<PickerFilters>): BoardState {
    const catalogue = bySide((side) => this.cardTargets.filter((card) => card.dataset.side === side).map(cardFrom))
    const received = bySide((side) =>
      this.lineTargets
        .filter((line) => line.dataset.side === side)
        .map((line): Line => ({ key: line.dataset.key ?? "", quantity: number(line.dataset.quantity) })),
    )
    return start({ catalogue, received, editing: this.editingValue, draft: readDraft(this.draftKeyValue), filters })
  }

  private seedFaces(): void {
    for (const face of this.faceTargets) {
      const key = face.dataset.key
      if (key && !this.faces.has(key)) this.faces.set(key, face)
    }
  }

  private receiveFaces(arrived: Readonly<Record<string, string>>): void {
    const faces = Object.entries(arrived)
    if (faces.length === 0) return
    for (const [key, html] of faces) this.faces.set(key, serverTemplate(html))
    this.render()
  }

  private requestFaces(keys: readonly string[]): void {
    if (this.facesUrlValue && keys.length > 0) this.loader.request(keys)
  }

  private render(): void {
    const state = this.state
    if (!state) return
    this.element.toggleAttribute("data-editing", state.editing)
    this.element.classList.toggle("trade-board--editing", state.editing)
    this.reflectHold()
    for (const outlet of this.tradeBoardSideOutlets) this.renderSide(state, outlet)
    const picker = this.picker()
    if (picker) this.renderPicker(state, picker)
  }

  private persist(): void {
    const state = this.state
    if (!state) return
    if (this.draftKeyValue) {
      if (changed(state)) saveDraft(this.draftKeyValue, draftSides(state))
      else forgetDraft(this.draftKeyValue)
    }
    if (this.hasTradeBoardSendOutlet) this.tradeBoardSendOutlet.reflect(!sendable(state))
  }

  private reflectHold(): void {
    const busy = this.swapping || (this.state !== undefined && (this.state.editing || this.state.picker !== null))
    holdLiveRefresh(this.element, busy)
  }

  private picker(): TradeBoardPickerController | null {
    return this.hasTradeBoardPickerOutlet ? this.tradeBoardPickerOutlet : null
  }

  private renderSide(state: BoardState, outlet: TradeBoardSideController): void {
    outlet.render(this.sideView(state, outlet.side), this.faceFor)
    this.requestFaces(state.lines[outlet.side].map((line) => line.key))
  }

  private renderPicker(state: BoardState, outlet: TradeBoardPickerController): void {
    const screen = this.pickerScreen(state)
    outlet.render(screen, this.faceFor)
    if (screen) this.requestFaces(screen.picks.map((pick) => pick.key))
  }

  private sideView(state: BoardState, side: Side): SideView {
    const lines = state.lines[side]
    return {
      lines: lines.flatMap((line) => {
        const card = cardOf(state, side, line.key)
        if (!card) return []
        return [
          {
            key: line.key,
            quantity: line.quantity,
            removeLabel: t(this.stringsValue.remove, { title: card.title }),
            stepper: card.max > 1 ? this.stepperView(card, line.quantity) : null,
          },
        ]
      }),
      count: this.countText(lines),
      canAdd: lines.length < MAX_CARDS,
      help: showsOpenHelp(side, lines),
    }
  }

  private pickerScreen(state: BoardState): PickerScreen | null {
    const view = pickerView(state)
    if (!view) return null
    const strings = this.stringsValue
    const picked = new Map(view.selection.map((line) => [line.key, line.quantity]))
    const picks = view.shownKeys.flatMap((key): PickView[] => {
      const card = cardOf(state, view.side, key)
      if (!card) return []
      const quantity = picked.get(key)
      const pressed = quantity !== undefined
      return [
        {
          key,
          pressed,
          disabled: card.max < 1 && !pressed,
          tabbable: key === view.activeKey,
          stepper: pressed && card.max > 1 ? this.stepperView(card, quantity) : null,
        },
      ]
    })
    return {
      side: view.side,
      picks,
      hasMore: view.hasMore,
      hasCards: view.hasCards,
      empty: view.empty,
      results: t(strings.results, { count: view.matches }),
      count: t(strings.picked, {
        cards: t(strings.pickedCards, { count: view.count.cards }),
        copies: t(strings.pickedCopies, { count: view.count.copies }),
      }),
      refused: view.refused,
      filter: view.filter,
      folded: view.folded,
      chipsOn: view.chipsOn,
      filtering: view.filtering,
    }
  }

  private stepperView(card: TradeCard, value: number): StepperView {
    const strings = this.stringsValue
    return {
      value,
      max: card.max,
      label: t(strings.quantityLabel, { title: card.title }),
      valueText: t(strings.valueText, { count: value, max: card.max }),
      maxText: t(strings.max, { max: card.max }),
      maxPhoneText: t(strings.maxPhone, { max: card.max }),
    }
  }

  private countText(lines: readonly Line[]): string {
    const { cards, copies } = sideCount(lines)
    const cardsText = t(this.stringsValue.cards, { count: cards })
    return copies === cards ? cardsText : t(this.stringsValue.cardsCopies, { count: cards, cards: cardsText, copies })
  }

  private focusSide({ side, key, preventScroll = false }: SideFocus): void {
    this.tradeBoardSideOutlets.find((outlet) => outlet.side === side)?.focus(key, preventScroll)
  }

  private focusOnArrival(): void {
    if (this.focusValue === "heading" && this.hasHeadingTarget) this.headingTarget.focus({ preventScroll: true })
    else if (this.focusValue === "side") this.focusSide({ side: "own", key: null, preventScroll: true })
  }

  private replaceUrl(url: string): void {
    if (!url) return
    const next = new URL(url, window.location.href)
    if (next.pathname === window.location.pathname) return
    window.history.replaceState(window.history.state, "", next)
    recordEntry(currentIndex(), next.pathname, sessionTrailStorage(), currentScreenLabel(), currentScreenLabels())
  }

  private playSwapOnce(): void {
    if (!this.swapValue) return
    this.swapValue = false
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    this.swapping = true
    this.reflectHold()
    this.playSwap()
  }

  private playSwap(): void {
    const friend = this.element.querySelector<HTMLElement>(".trade-side--friend .trade-side__cards")
    const own = this.element.querySelector<HTMLElement>(".trade-side--own .trade-side__cards")
    if (!friend || !own || typeof this.element.animate !== "function") {
      this.finishSwap()
      return
    }

    if (motionReduced()) {
      for (const list of [friend, own]) {
        this.animations.push(list.animate([{ opacity: 0 }, { opacity: 1 }], { duration: SWAP_CROSSFADE_MS, easing: "ease-out" }))
      }
      this.later(SWAP_CROSSFADE_MS, () => this.finishSwap())
      return
    }

    const from = { friend: centre(own), own: centre(friend) }
    const to = { friend: centre(friend), own: centre(own) }
    this.reflectSwapping(true)
    for (const [list, side] of [
      [friend, "friend"],
      [own, "own"],
    ] as const) {
      const offset = { x: from[side].x - to[side].x, y: from[side].y - to[side].y }
      for (const card of list.querySelectorAll<HTMLElement>(":scope > .trade-card")) {
        this.animations.push(card.animate(swapKeyframes(offset), { duration: SWAP_MS, easing: "linear", fill: "backwards" }))
      }
    }
    this.later(SWAP_MS * SWAP_BURST_AT, () => this.burst())
    this.later(SWAP_MS, () => this.finishSwap())
  }

  private burst(): void {
    const middle = this.element.querySelector<HTMLElement>(".trade-board__middle")
    if (!middle) return
    this.effect("trade-swap__ring", middle)
    confettiDirections(CONFETTI, CONFETTI_REACH).forEach((direction, index) => {
      const piece = this.effect(`trade-swap__confetti trade-swap__confetti--${index % 4}`, middle)
      piece.style.setProperty("--confetti-x", `${direction.x}px`)
      piece.style.setProperty("--confetti-y", `${direction.y}px`)
    })
    this.effect("trade-swap__flash", this.element)
    this.later(BURST_MS, () => {
      this.effects.forEach((effect) => effect.remove())
      this.effects = []
    })
  }

  private effect(className: string, parent: HTMLElement): HTMLElement {
    const element = document.createElement("span")
    element.className = className
    element.setAttribute("aria-hidden", "true")
    parent.append(element)
    this.effects.push(element)
    return element
  }

  private finishSwap(): void {
    this.swapping = false
    this.reflectSwapping(false)
    this.reflectHold()
    this.element.querySelector<HTMLElement>(".trade-board__message")?.focus({ preventScroll: true })
  }

  private stopSwap(): void {
    this.animations.forEach((animation) => animation.cancel())
    this.timers.forEach((timer) => window.clearTimeout(timer))
    this.effects.forEach((effect) => effect.remove())
    this.animations = []
    this.timers = []
    this.effects = []
    this.swapping = false
    this.reflectSwapping(false)
    holdLiveRefresh(this.element, false)
  }

  private reflectSwapping(swapping: boolean): void {
    this.element.toggleAttribute("data-swapping", swapping)
    this.element.classList.toggle("trade-board--swapping", swapping)
  }

  private later(delay: number, callback: () => void): void {
    this.timers.push(window.setTimeout(callback, delay))
  }
}

export default TradeBoardController
