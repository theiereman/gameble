import { Controller } from "@hotwired/stimulus"
import {
  activeKey,
  clearRefusal,
  gameLabel,
  gamesUrl,
  initialState,
  isFilter,
  isPicked,
  move,
  reset,
  setActive,
  setFilter,
  setQuery,
  toggle,
  type EditorState,
} from "../lib/custom_set_editor"
import { writeText } from "../lib/dom_writes"
import { columnsOf } from "../lib/grid_keys"
import { t, type Template } from "../lib/i18n"
import { Debounce } from "../lib/set_search"
import { cloneContent, cloneFirstElement } from "../lib/templates"

type EditorStrings = { games: Template; inSet: string; nameCount: string; picked: Template }

const TYPING_PAUSE_MS = 250
const FLASH_MS = 400
const PICKED = "custom-set-game--picked"
const REFUSED = "custom-set-game--refused"
const TOGGLE = ".custom-set-game__toggle"

export default class CustomSetEditorController extends Controller<HTMLDialogElement> {
  static targets = [
    "name",
    "nameCount",
    "inputs",
    "search",
    "chip",
    "pickedChip",
    "body",
    "frame",
    "grid",
    "page",
    "game",
    "count",
    "refusal",
    "inputTemplate",
    "limitTemplate",
  ]
  static values = { gamesUrl: String, max: Number, nameLimit: Number, strings: Object }

  declare readonly nameTarget: HTMLInputElement
  declare readonly nameCountTarget: HTMLElement
  declare readonly inputsTarget: HTMLElement
  declare readonly searchTarget: HTMLInputElement
  declare readonly chipTargets: HTMLInputElement[]
  declare readonly pickedChipTarget: HTMLElement
  declare readonly bodyTarget: HTMLElement
  declare readonly frameTarget: HTMLElement
  declare readonly hasGridTarget: boolean
  declare readonly gridTarget: HTMLUListElement
  declare readonly gameTargets: HTMLLIElement[]
  declare readonly countTarget: HTMLElement
  declare readonly refusalTarget: HTMLElement
  declare readonly inputTemplateTarget: HTMLTemplateElement
  declare readonly limitTemplateTarget: HTMLTemplateElement
  declare readonly gamesUrlValue: string
  declare readonly maxValue: number
  declare readonly nameLimitValue: number
  declare readonly stringsValue: EditorStrings

  private state: EditorState = initialState("", [])
  private loadedUrl = ""
  private rovingQueued = false
  private readonly debounce = new Debounce(TYPING_PAUSE_MS)
  private readonly flashes = new Map<HTMLElement, number>()

  connect(): void {
    const picks = Array.from(this.inputsTarget.querySelectorAll<HTMLInputElement>("input"), (input) => input.value)
    this.state = initialState(this.nameTarget.defaultValue, picks)
    this.loadedUrl = this.frameTarget.getAttribute("src") ?? ""
    for (const item of this.gameTargets) this.reflectGame(item)
    this.reflectRoving()
  }

  disconnect(): void {
    this.debounce.cancel()
    for (const timer of this.flashes.values()) window.clearTimeout(timer)
    this.flashes.clear()
  }

  gameTargetConnected(item: HTMLLIElement): void {
    this.reflectGame(item)
    this.queueRoving()
  }

  pageTargetConnected(list: HTMLUListElement): void {
    if (!this.hasGridTarget) return
    const first = list.querySelector<HTMLElement>(TOGGLE)
    const focusLost = !this.element.contains(document.activeElement)
    this.gridTarget.append(...Array.from(list.children))
    list.remove()
    if (!first || !focusLost) return
    this.state = setActive(this.state, this.keyOf(first) ?? null)
    this.reflectRoving()
    first.focus()
  }

  named(): void {
    this.state = clearRefusal(this.state)
    this.renderName()
    this.renderRefusal()
  }

  typed(event: Event): void {
    if ((event as InputEvent).isComposing) return
    this.state = setQuery(this.state, this.searchTarget.value)
    this.debounce.call(() => this.load())
  }

  filtered(event: Event): void {
    const value = (event.target as HTMLInputElement).value
    if (!isFilter(value)) return
    this.state = setFilter(this.state, value)
    this.debounce.cancel()
    this.load()
  }

  toggle(event: Event): void {
    const item = (event.currentTarget as Element).closest<HTMLLIElement>(".custom-set-game")
    const key = item && this.keyOf(item)
    if (!item || !key) return
    const { state, refused } = toggle(this.state, key, this.maxValue)
    this.state = state
    if (refused) this.flash(item)
    this.renderPicks()
    this.renderRefusal()
  }

  keydown(event: KeyboardEvent): void {
    if (!(event.target instanceof Element) || !event.target.matches(TOGGLE)) return
    const items = this.gameTargets
    const keys = items.map((item) => this.keyOf(item) ?? "")
    const next = move(this.state, keys, event.key, columnsOf(items.map((item) => item.offsetTop)))
    if (next === null) return
    event.preventDefault()
    this.state = setActive(this.state, next)
    this.reflectRoving()
    items[keys.indexOf(next)]?.querySelector<HTMLElement>(TOGGLE)?.focus()
  }

  closed(): void {
    this.debounce.cancel()
    this.state = reset(this.state)
    this.nameTarget.value = this.state.openedWith.name
    this.searchTarget.value = ""
    for (const chip of this.chipTargets) chip.checked = chip.value === this.state.filter
    this.renderName()
    this.renderPicks()
    this.renderRefusal()
    this.load()
  }

  private load(): void {
    const url = gamesUrl(this.gamesUrlValue, this.state)
    if (url === this.loadedUrl) return
    this.loadedUrl = url
    this.frameTarget.setAttribute("src", url)
    this.bodyTarget.scrollTop = 0
  }

  private renderName(): void {
    writeText(
      this.nameCountTarget,
      t(this.stringsValue.nameCount, { count: this.nameTarget.value.length, max: this.nameLimitValue }),
    )
  }

  private renderPicks(): void {
    const count = this.state.picks.length
    writeText(this.countTarget, t(this.stringsValue.games, { count }))
    writeText(this.pickedChipTarget, t(this.stringsValue.picked, { count }))
    this.inputsTarget.replaceChildren(...this.state.picks.flatMap((pick) => this.input(pick)))
    for (const item of this.gameTargets) this.reflectGame(item)
    this.reflectRoving()
  }

  private renderRefusal(): void {
    if (this.state.refusal === "limit") this.refusalTarget.replaceChildren(cloneContent(this.limitTemplateTarget))
    else this.refusalTarget.replaceChildren()
  }

  private input(pick: string): HTMLInputElement[] {
    const input = cloneFirstElement<HTMLInputElement>(this.inputTemplateTarget)
    if (!input) return []
    input.value = pick
    return [input]
  }

  private reflectGame(item: HTMLElement): void {
    const key = this.keyOf(item)
    const toggle = item.querySelector<HTMLElement>(TOGGLE)
    if (!key || !toggle) return
    const picked = isPicked(this.state, key)
    item.classList.toggle(PICKED, picked)
    toggle.setAttribute("aria-pressed", String(picked))
    toggle.setAttribute("aria-label", gameLabel(toggle.dataset.label ?? "", picked, this.stringsValue.inSet))
  }

  private queueRoving(): void {
    if (this.rovingQueued) return
    this.rovingQueued = true
    queueMicrotask(() => {
      this.rovingQueued = false
      this.reflectRoving()
    })
  }

  private reflectRoving(): void {
    const items = this.gameTargets
    const active = activeKey(
      this.state,
      items.map((item) => this.keyOf(item) ?? ""),
    )
    for (const item of items) {
      const toggle = item.querySelector<HTMLElement>(TOGGLE)
      if (toggle) toggle.tabIndex = this.keyOf(item) === active ? 0 : -1
    }
  }

  private flash(item: HTMLElement): void {
    window.clearTimeout(this.flashes.get(item))
    item.classList.remove(REFUSED)
    void item.offsetWidth
    item.classList.add(REFUSED)
    this.flashes.set(
      item,
      window.setTimeout(() => {
        item.classList.remove(REFUSED)
        this.flashes.delete(item)
      }, FLASH_MS),
    )
  }

  private keyOf(element: Element): string | undefined {
    return element.closest<HTMLElement>(".custom-set-game")?.dataset.key
  }
}
