import { Controller } from "@hotwired/stimulus"
import { openDialog } from "../lib/dialog"
import { currentIndex, currentScreenLabel, currentScreenLabels, recordEntry, sessionTrailStorage } from "../lib/history_trail"
import { holdLiveRefresh } from "../lib/live_refresh_hold"
import { opensElsewhere, type Intent } from "../lib/screen"
import { serverTemplate } from "../lib/server_html"
import { cloneContent } from "../lib/templates"
import {
  bySide,
  changed,
  clearFilters,
  closePicker,
  draftSides,
  edit,
  moveActive,
  openPicker,
  place,
  removeLine,
  restore,
  sendable,
  setFilter,
  setLineQuantity,
  setPickQuantity,
  showMore,
  start,
  toggleFold,
  togglePick,
  type BoardState,
  type PickerFilters,
  type BySide,
  type Side,
  type SideFilter,
} from "../lib/trade_board"
import { forgetDraft, readDraft, saveDraft } from "../lib/trade_board_draft"
import { faceLoader, facesUrl, fetchFaces, type FaceLoader } from "../lib/trade_board_faces"
import { cardFrom, lineFrom } from "../lib/trade_board_markup"
import { swapStage, type SwapStage } from "../lib/trade_board_swap_stage"
import { pickerScreenOf, sideViewOf, type BoardStrings } from "../lib/trade_board_views"
import type TradeBoardPickerController from "./trade_board_picker_controller"
import type { MoveIntent } from "./trade_board_picker_controller"
import type TradeBoardSendController from "./trade_board_send_controller"
import type TradeBoardSideController from "./trade_board_side_controller"
import type { SideIntent } from "./trade_board_side_controller"

type SideFocus = { side: Side; key: string | null; preventScroll?: boolean }

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
  private swap!: SwapStage
  private faces = new Map<string, HTMLTemplateElement>()
  private loader!: FaceLoader

  private readonly faceFor = (key: string): DocumentFragment | null => {
    const template = this.faces.get(key)
    return template ? cloneContent(template) : null
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
    this.swap = swapStage(this.element, () => this.reflectHold())
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
    this.swap.stop()
    holdLiveRefresh(this.element, false)
    this.state = undefined
  }

  tradeBoardSideOutletConnected(outlet: TradeBoardSideController): void {
    if (this.state) this.renderSide(this.state, outlet)
  }

  tradeBoardPickerOutletConnected(outlet: TradeBoardPickerController): void {
    if (this.state) this.renderPicker(this.state, outlet)
  }

  tradeBoardSendOutletConnected(outlet: TradeBoardSendController): void {
    if (this.state) outlet.render(!sendable(this.state))
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
    const catalogue = bySide((side) => this.cardTargets.filter((card) => card.dataset.side === side).map((card) => cardFrom(card.dataset)))
    const received = bySide((side) =>
      this.lineTargets
        .filter((line) => line.dataset.side === side)
        .map((line) => lineFrom(line.dataset)),
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
    if (this.hasTradeBoardSendOutlet) this.tradeBoardSendOutlet.render(!sendable(state))
  }

  private reflectHold(): void {
    const busy = this.swap.playing || (this.state !== undefined && (this.state.editing || this.state.picker !== null))
    holdLiveRefresh(this.element, busy)
  }

  private picker(): TradeBoardPickerController | null {
    return this.hasTradeBoardPickerOutlet ? this.tradeBoardPickerOutlet : null
  }

  private renderSide(state: BoardState, outlet: TradeBoardSideController): void {
    outlet.render(sideViewOf(state, outlet.side, this.stringsValue), this.faceFor)
    this.requestFaces(state.lines[outlet.side].map((line) => line.key))
  }

  private renderPicker(state: BoardState, outlet: TradeBoardPickerController): void {
    const screen = pickerScreenOf(state, this.stringsValue)
    outlet.render(screen, this.faceFor)
    if (screen) this.requestFaces(screen.picks.map((pick) => pick.key))
  }

  private focusSide({ side, key, preventScroll = false }: SideFocus): void {
    this.tradeBoardSideOutlets.find((outlet) => outlet.side === side)?.focus(key, preventScroll)
  }

  private focusOnArrival(): void {
    if (this.focusValue === "heading" && this.hasHeadingTarget) this.headingTarget.focus({ preventScroll: true })
    else if (this.focusValue === "side") this.focusSide({ side: "own", key: null, preventScroll: true })
  }

  private playSwapOnce(): void {
    if (!this.swapValue) return
    this.swapValue = false
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    this.swap.play()
  }

  private replaceUrl(url: string): void {
    if (!url) return
    const next = new URL(url, window.location.href)
    if (next.pathname === window.location.pathname) return
    window.history.replaceState(window.history.state, "", next)
    recordEntry(currentIndex(), next.pathname, sessionTrailStorage(), currentScreenLabel(), currentScreenLabels())
  }
}

export default TradeBoardController
