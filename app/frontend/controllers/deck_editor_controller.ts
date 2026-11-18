import { Controller } from "@hotwired/stimulus"
import { csrfToken } from "../lib/booster_page"
import type { Intent } from "../lib/screen"
import type { Percentiles } from "../lib/deck_collection_order"
import {
  activateFirst,
  choose,
  chooseGap,
  collectionView,
  countOf,
  failed,
  filterBy,
  focusAfterRemoval,
  move,
  nextToSend,
  noticeText,
  refused,
  removeSlot,
  rename,
  requestFor,
  saved,
  slotsView,
  searchFor,
  showMore,
  sortBy,
  start,
  SLOT_COUNT,
  type Availability,
  type DeckState,
  type DeckStrings,
  type Entry,
} from "../lib/deck_editor"
import { sendChange } from "../lib/deck_editor_save"
import { writeAttribute, writeHidden, writeText } from "../lib/dom_writes"
import { t } from "../lib/i18n"
import type DeckCollectionController from "./deck_collection_controller"
import type { MoveIntent } from "./deck_collection_controller"
import type DeckCoverageController from "./deck_coverage_controller"
import type DeckNameController from "./deck_name_controller"
import type DeckSlotsController from "./deck_slots_controller"

function percentilesFrom(json: string | undefined): Percentiles {
  try {
    const parsed: unknown = JSON.parse(json ?? "{}")
    return typeof parsed === "object" && parsed !== null ? (parsed as Percentiles) : {}
  } catch {
    return {}
  }
}

function entryFrom(element: HTMLElement): Entry {
  const data = element.dataset
  return {
    ref: data.ref ?? "",
    game: data.game ?? "",
    title: data.title ?? "",
    image: data.image ?? "",
    availability: (data.availability ?? "available") as Availability,
    percentiles: percentilesFrom(data.percentiles),
    trump: data.trump ?? "",
    movesText: data.movesText ?? "",
    movesSentence: data.movesSentence ?? "",
  }
}

export default class DeckEditorController extends Controller<HTMLElement> {
  static targets = [
    "entry",
    "slot",
    "summaryName",
    "count",
    "countHidden",
    "status",
    "saveState",
    "deleteArea",
    "deleteForm",
    "deleteTitle",
  ]
  static values = { token: String, name: String, createUrl: String, deckUrl: String, strings: Object, coverage: Array }
  static outlets = ["deck-name", "deck-coverage", "deck-slots", "deck-collection"]

  declare readonly entryTargets: HTMLElement[]
  declare readonly slotTargets: HTMLElement[]
  declare readonly summaryNameTarget: HTMLElement
  declare readonly countTarget: HTMLElement
  declare readonly countHiddenTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly saveStateTarget: HTMLElement
  declare readonly deleteAreaTarget: HTMLElement
  declare readonly deleteFormTarget: HTMLFormElement
  declare readonly deleteTitleTarget: HTMLElement
  declare readonly tokenValue: string
  declare readonly nameValue: string
  declare readonly createUrlValue: string
  declare readonly deckUrlValue: string
  declare readonly stringsValue: DeckStrings
  declare readonly coverageValue: unknown
  declare readonly hasDeckNameOutlet: boolean
  declare readonly deckNameOutlet: DeckNameController
  declare readonly hasDeckCoverageOutlet: boolean
  declare readonly deckCoverageOutlet: DeckCoverageController
  declare readonly hasDeckSlotsOutlet: boolean
  declare readonly deckSlotsOutlet: DeckSlotsController
  declare readonly hasDeckCollectionOutlet: boolean
  declare readonly deckCollectionOutlet: DeckCollectionController

  private state?: DeckState
  private announced = 0
  private flushing = false
  private hasSaved = false
  private leaveTo: string | null = null

  connect(): void {
    this.state = start({
      token: this.tokenValue,
      url: this.deckUrlValue,
      name: this.nameValue,
      slots: this.slotTargets.map((slot) => slot.dataset.ref || null),
      entries: this.entryTargets.map(entryFrom),
      coverage: this.coverageValue,
    })
    this.announced = 0
    this.render()
  }

  disconnect(): void {
    this.state = undefined
  }

  deckNameOutletConnected(): void {
    this.render()
  }

  deckCoverageOutletConnected(): void {
    this.render()
  }

  deckSlotsOutletConnected(): void {
    this.render()
  }

  deckCollectionOutletConnected(): void {
    this.render()
  }

  choose({ detail: { ref } }: Intent<{ ref: string }>): void {
    if (!this.state) return
    this.apply(choose(this.state, ref))
    this.flush()
  }

  removeSlot({ detail: { slot } }: Intent<{ slot: number }>): void {
    if (!this.state) return
    const next = removeSlot(this.state, slot)
    if (next === this.state) return
    const focus = focusAfterRemoval(next, slot)
    this.apply(focus === null ? activateFirst(next) : next)
    if (focus === null) this.collection()?.focusActive()
    else this.slots()?.focusSlot(focus)
    this.flush()
  }

  rename({ detail: { name } }: Intent<{ name: string }>): void {
    if (!this.state) return
    this.apply(rename(this.state, name))
    this.flush()
  }

  chooseGap({ detail: { call } }: Intent<{ call: string }>): void {
    if (!this.state) return
    this.apply(chooseGap(this.state, call))
  }

  search({ detail: { query } }: Intent<{ query: string }>): void {
    if (this.state) this.apply(searchFor(this.state, query))
  }

  more(): void {
    if (this.state) this.apply(showMore(this.state))
  }

  sortBy({ detail: { sort } }: Intent<{ sort: string }>): void {
    if (!this.state) return
    this.apply(sortBy(this.state, sort))
  }

  filterBy({ detail: { trump } }: Intent<{ trump: string }>): void {
    if (!this.state) return
    this.apply(filterBy(this.state, trump))
  }

  move(event: Intent<MoveIntent>): void {
    if (!this.state) return
    const next = move(this.state, event.detail.key, event.detail.columns)
    if (next === this.state) return
    event.preventDefault()
    this.apply(next)
    this.collection()?.focusActive()
  }

  // "Save" leaves for the duels screen, once the changes still on their way have been saved.
  finish(event: Event): void {
    const link = (event.target as Element).closest("a")
    if (!link || !this.state || (!this.flushing && this.state.pending.length === 0)) return
    event.preventDefault()
    this.leaveTo = link.href
    void this.flush()
  }

  private async flush(): Promise<void> {
    if (this.flushing) return
    this.flushing = true
    try {
      for (let change = this.state && nextToSend(this.state); this.state && change; change = nextToSend(this.state)) {
        const request = requestFor(this.state, change, this.createUrlValue)
        if (!request) break
        const result = await sendChange({ ...request, csrfToken: csrfToken() })
        if (!this.state) return
        if (result.kind === "failed") {
          this.apply(failed(this.state))
          break
        }
        const wasNew = this.state.token === null
        if (result.kind === "saved") this.hasSaved = true
        this.apply(
          result.kind === "saved" ? saved(this.state, result.body) : refused(this.state, result.code, result.message),
        )
        if (wasNew && this.state.url) window.history.replaceState(window.history.state, "", this.state.url)
      }
    } finally {
      this.flushing = false
      if (this.leaveTo && this.state?.pending.length === 0) window.Turbo.visit(this.leaveTo)
    }
  }

  private apply(next: DeckState): void {
    if (next === this.state) return
    this.state = next
    this.render()
  }

  private render(): void {
    const state = this.state
    if (!state) return
    const strings = this.stringsValue
    const count = countOf(state)
    this.deckName()?.render({ name: state.name, refusal: state.nameRefusal })
    if (state.coverage) this.coverage()?.render(state.coverage)
    this.slots()?.render(slotsView(state, strings))
    this.collection()?.render(collectionView(state), strings)
    writeText(this.summaryNameTarget, state.name)
    writeText(this.countTarget, `${count} / ${SLOT_COUNT}`)
    writeText(this.countHiddenTarget, t(strings.countHidden, { count }))
    writeText(this.deleteTitleTarget, t(strings.deleteTitle, { deck: state.savedName }))
    this.renderSaveState(state, strings)
    writeHidden(this.deleteAreaTarget, state.url === null)
    if (state.url) writeAttribute(this.deleteFormTarget, "action", state.url)
    this.announce(state)
  }

  private renderSaveState(state: DeckState, strings: DeckStrings): void {
    const saveState =
      state.notice?.kind === "save_failed"
        ? "failed"
        : state.pending.length > 0
          ? "saving"
          : this.hasSaved
            ? "saved"
            : ""
    const label = { failed: strings.saveStateFailed, saving: strings.saveStateSaving, saved: strings.saveStateSaved }
    writeAttribute(this.saveStateTarget, "data-state", saveState)
    writeText(this.saveStateTarget, saveState ? label[saveState] : "")
  }

  private announce(state: DeckState): void {
    if (state.noticeCount === this.announced) return
    this.announced = state.noticeCount
    const message = noticeText(state, this.stringsValue)
    this.statusTarget.textContent = ""
    window.requestAnimationFrame(() => writeText(this.statusTarget, message))
  }

  private deckName(): DeckNameController | null {
    return this.hasDeckNameOutlet ? this.deckNameOutlet : null
  }

  private coverage(): DeckCoverageController | null {
    return this.hasDeckCoverageOutlet ? this.deckCoverageOutlet : null
  }

  private slots(): DeckSlotsController | null {
    return this.hasDeckSlotsOutlet ? this.deckSlotsOutlet : null
  }

  private collection(): DeckCollectionController | null {
    return this.hasDeckCollectionOutlet ? this.deckCollectionOutlet : null
  }
}
