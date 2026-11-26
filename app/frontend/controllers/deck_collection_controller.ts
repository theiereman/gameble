import { Controller } from "@hotwired/stimulus"
import type { CollectionView, DeckStrings } from "../lib/deck_editor"
import { writeAttribute, writeChecked, writeFlag, writeHidden, writeText } from "../lib/dom_writes"
import { columnsOf } from "../lib/grid_keys"

export type MoveIntent = { key: string; columns: number }

function recommendation(ref: string, source: HTMLLIElement): HTMLLIElement {
  const item = source.cloneNode(true) as HTMLLIElement
  item.hidden = false
  item.dataset.ref = ref
  const button = item.querySelector<HTMLElement>(".deck-entry__toggle")
  if (button) {
    button.dataset.deckCollectionTarget = "pick"
    delete button.dataset.deckEditorTarget
    button.tabIndex = 0
  }
  return item
}

const sortOf = (option: HTMLAnchorElement): string => new URL(option.href).searchParams.get("sort") ?? ""

export default class DeckCollectionController extends Controller<HTMLElement> {
  static targets = ["empty", "entry", "list", "more", "pick", "recommendations", "recommended", "sortOption", "trump"]
  static values = { facesUrl: String }

  declare readonly entryTargets: HTMLElement[]
  declare readonly hasListTarget: boolean
  declare readonly listTarget: HTMLElement
  declare readonly sortOptionTargets: HTMLAnchorElement[]
  declare readonly trumpTargets: HTMLInputElement[]
  declare readonly hasEmptyTarget: boolean
  declare readonly emptyTarget: HTMLElement
  declare readonly pickTargets: HTMLElement[]
  declare readonly hasRecommendedTarget: boolean
  declare readonly recommendedTarget: HTMLElement
  declare readonly hasRecommendationsTarget: boolean
  declare readonly recommendationsTarget: HTMLElement
  declare readonly hasMoreTarget: boolean
  declare readonly moreTarget: HTMLElement
  declare readonly facesUrlValue: string

  private readonly requestedFaces = new Set<string>()

  render({ sort, trump, remaining, matches, recommended, entries }: CollectionView, strings: DeckStrings): void {
    this.reorder([...entries.keys()])
    this.showRecommended(recommended)
    for (const entry of [...this.entryTargets, ...this.pickTargets]) {
      const state = entries.get(entry.dataset.ref ?? "")
      if (!state) continue
      if (!entry.matches("[data-deck-collection-target~='pick']")) {
        writeHidden(entry.closest("li"), state.hidden)
        writeAttribute(entry, "tabindex", state.tabbable ? "0" : "-1")
      }
      writeAttribute(entry, "aria-pressed", String(state.inDeck))
      writeAttribute(entry, "aria-label", `${entry.dataset.label ?? ""}${state.inDeck ? strings.inDeckSuffix : ""}`)
      writeText(entry.querySelector(".deck-entry__action"), state.inDeck ? strings.inDeck : strings.add)
    }
    for (const option of this.sortOptionTargets) {
      const current = sortOf(option) === sort
      writeFlag(option, "aria-current", current)
      if (current) writeText(this.element.querySelector(".sort__current"), option.textContent ?? "")
    }
    if (this.hasEmptyTarget) writeHidden(this.emptyTarget, matches > 0)
    if (this.hasMoreTarget) writeHidden(this.moreTarget, remaining === 0)
    for (const radio of this.trumpTargets) writeChecked(radio, radio.value === trump)
    this.drawMissingFaces()
  }

  focusActive(): void {
    this.entryTargets.find((entry) => entry.getAttribute("tabindex") === "0")?.focus()
  }

  choose(event: Event): void {
    const ref = (event.currentTarget as HTMLElement).dataset.ref
    if (ref) this.dispatch("choose", { detail: { ref } })
  }

  search(event: Event): void {
    this.dispatch("search", { detail: { query: (event.currentTarget as HTMLInputElement).value } })
  }

  more(event: Event): void {
    if (event.target instanceof Element && event.target.closest("button")) this.dispatch("more")
  }

  sort(event: Event): void {
    event.preventDefault()
    const option = event.currentTarget as HTMLAnchorElement
    const menu = option.closest("details")
    if (menu) {
      menu.open = false
      menu.querySelector("summary")?.focus()
    }
    this.dispatch("sort", { detail: { sort: sortOf(option) } })
  }

  filter(event: Event): void {
    const radio = event.currentTarget as HTMLInputElement
    if (radio.checked) this.dispatch("filter", { detail: { trump: radio.value } })
  }

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof HTMLElement) || !this.entryTargets.includes(event.target)) return
    const detail: MoveIntent = { key: event.key, columns: columnsOf(this.firstRowTops()) }
    const sent = this.dispatch("move", { detail })
    if (sent.defaultPrevented) event.preventDefault()
  }

  // The server draws the first page of the collection; the cards shown later fetch their faces.
  private drawMissingFaces(): void {
    const missing = this.facelessShown().filter((ref) => !this.requestedFaces.has(ref))
    if (missing.length === 0 || !this.facesUrlValue) return
    for (const ref of missing) this.requestedFaces.add(ref)
    const query = new URLSearchParams(missing.map((ref) => ["refs[]", ref]))
    void fetch(`${this.facesUrlValue}?${query}`, { headers: { Accept: "text/html" } })
      .then((response) => (response.ok ? response.text() : ""))
      .catch(() => "")
      .then((html) => this.placeFaces(html, missing))
  }

  private facelessShown(): string[] {
    const refs = [...this.entryTargets, ...this.pickTargets]
      .filter((entry) => !entry.closest("li")?.hidden && !entry.querySelector(".deck-card"))
      .map((entry) => entry.dataset.ref ?? "")
    return [...new Set(refs)].filter(Boolean)
  }

  private placeFaces(html: string, asked: readonly string[]): void {
    const faces = new DOMParser().parseFromString(html, "text/html").querySelectorAll("template")
    const byRef = new Map(Array.from(faces, (face) => [face.dataset.ref ?? "", face]))
    for (const entry of [...this.entryTargets, ...this.pickTargets]) {
      const face = byRef.get(entry.dataset.ref ?? "")
      if (face && !entry.querySelector(".deck-card")) entry.prepend(face.content.cloneNode(true))
    }
    for (const ref of asked) if (!byRef.has(ref)) this.requestedFaces.delete(ref)
  }

  private showRecommended(refs: readonly string[]): void {
    if (!this.hasRecommendedTarget) return
    if (this.hasRecommendationsTarget) writeHidden(this.recommendationsTarget, refs.length === 0)
    const shown = Array.from(this.recommendedTarget.children).map((item) => (item as HTMLElement).dataset.ref ?? "")
    if (shown.join() === refs.join()) return
    const sources = new Map(this.entryTargets.map((entry) => [entry.dataset.ref ?? "", entry.closest("li")]))
    const items = refs.flatMap((ref) => {
      const source = sources.get(ref)
      return source ? [recommendation(ref, source)] : []
    })
    this.recommendedTarget.replaceChildren(...items)
  }

  private reorder(order: readonly string[]): void {
    if (!this.hasListTarget) return
    const items = new Map(this.entryTargets.map((entry) => [entry.dataset.ref ?? "", entry.closest("li")]))
    const wanted = order
      .map((ref) => items.get(ref))
      .filter((item): item is HTMLLIElement => item instanceof HTMLLIElement)
    const current = Array.from(this.listTarget.children)
    if (wanted.every((item, index) => current[index] === item)) return
    this.listTarget.append(...wanted)
  }

  private firstRowTops(): number[] {
    const tops: number[] = []
    for (const entry of this.entryTargets) {
      if (entry.closest("li")?.hidden) continue
      tops.push(entry.offsetTop)
      if (entry.offsetTop !== tops[0]) break
    }
    return tops
  }
}
