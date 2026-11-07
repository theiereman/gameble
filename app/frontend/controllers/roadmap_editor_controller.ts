import { Controller } from "@hotwired/stimulus"
import {
  applyKeys,
  indexToFocusAfterRemoval,
  isDirection,
  neighbourIndex,
  nextKey,
  type KeyReplacements,
} from "../lib/roadmap_editor"
import { Debounce } from "../lib/set_search"
import { cloneFirstElement } from "../lib/templates"

const ROW = "[data-roadmap-row]"
const LIST = "[data-roadmap-list]"
const PREVIEW_PAUSE_MS = 400

export default class RoadmapEditorController extends Controller<HTMLFormElement> {
  static targets = ["milestones", "milestoneTemplate", "storyTemplate", "previewButton"]
  static values = { milestoneKey: String, storyKey: String }

  declare readonly milestonesTarget: HTMLElement
  declare readonly milestoneTemplateTarget: HTMLTemplateElement
  declare readonly storyTemplateTarget: HTMLTemplateElement
  declare readonly previewButtonTarget: HTMLButtonElement
  declare readonly milestoneKeyValue: string
  declare readonly storyKeyValue: string

  private readonly debounce = new Debounce(PREVIEW_PAUSE_MS)

  connect(): void {
    this.refresh()
  }

  disconnect(): void {
    this.debounce.cancel()
  }

  addMilestone(): void {
    const row = this.build(this.milestoneTemplateTarget, { [this.milestoneKeyValue]: this.freshKey() })
    if (row) this.append(this.milestonesTarget, row)
  }

  addStory(event: Event): void {
    const milestone = this.rowOf(event.currentTarget)
    const list = milestone?.querySelector<HTMLElement>(`:scope > ${LIST}`)
    if (!milestone || !list) return

    const row = this.build(this.storyTemplateTarget, {
      [this.milestoneKeyValue]: milestone.dataset.key ?? "",
      [this.storyKeyValue]: this.freshKey(),
    })
    if (row) this.append(list, row)
  }

  move(event: Event & { params: { direction?: unknown } }): void {
    const { direction } = event.params
    const row = this.rowOf(event.currentTarget)
    if (!row || !isDirection(direction)) return

    const rows = this.rowsBesides(row)
    const target = neighbourIndex(rows.length, rows.indexOf(row), direction)
    if (target === null) return

    if (direction === "up") rows[target].before(row)
    else rows[target].after(row)
    this.refresh()
    this.focusMove(row, direction)
    this.schedulePreview()
  }

  remove(event: Event & { params: { confirm?: unknown } }): void {
    const row = this.rowOf(event.currentTarget)
    if (!row || !window.confirm(String(event.params.confirm ?? ""))) return

    const rows = this.rowsBesides(row)
    const next = indexToFocusAfterRemoval(rows.length, rows.indexOf(row))
    const list = row.parentElement
    row.remove()
    this.refresh()
    if (next === null) this.adderOf(list)?.focus()
    else rows[next].querySelector<HTMLElement>("input, select")?.focus()
    this.schedulePreview()
  }

  changed(): void {
    this.schedulePreview()
  }

  submitted(event: SubmitEvent): void {
    if (event.submitter !== this.previewButtonTarget) this.debounce.cancel()
  }

  private build(template: HTMLTemplateElement, replacements: KeyReplacements): HTMLElement | null {
    const row = cloneFirstElement<HTMLElement>(template)
    if (row) applyKeys(row, replacements)
    return row
  }

  private append(list: HTMLElement, row: HTMLElement): void {
    list.append(row)
    this.refresh()
    row.querySelector<HTMLElement>("input")?.focus()
    this.schedulePreview()
  }

  private freshKey(): string {
    return nextKey(Array.from(this.element.querySelectorAll<HTMLElement>("[data-key]"), (row) => row.dataset.key ?? ""))
  }

  private adderOf(list: Element | null): HTMLElement | null | undefined {
    const owner = list?.closest<HTMLElement>(ROW)
    return owner
      ? owner.querySelector<HTMLElement>("[data-action$='#addStory']")
      : this.element.querySelector<HTMLElement>("[data-action$='#addMilestone']")
  }

  private rowOf(target: EventTarget | null): HTMLElement | null {
    return target instanceof Element ? target.closest<HTMLElement>(ROW) : null
  }

  private rowsBesides(row: HTMLElement): HTMLElement[] {
    return Array.from(row.parentElement?.children ?? []).filter((child): child is HTMLElement => child.matches(ROW))
  }

  private refresh(): void {
    for (const list of this.element.querySelectorAll<HTMLElement>(LIST)) {
      const rows = Array.from(list.children).filter((child): child is HTMLElement => child.matches(ROW))
      rows.forEach((row, index) => {
        this.moveButton(row, "up").disabled = index === 0
        this.moveButton(row, "down").disabled = index === rows.length - 1
      })
    }
  }

  private moveButton(row: HTMLElement, direction: string): HTMLButtonElement {
    return row.querySelector<HTMLButtonElement>(`:scope > .roadmap-row__actions [data-roadmap-move='${direction}']`)!
  }

  private focusMove(row: HTMLElement, direction: string): void {
    const same = this.moveButton(row, direction)
    const other = this.moveButton(row, direction === "up" ? "down" : "up")
    ;(same.disabled ? other : same).focus()
  }

  private schedulePreview(): void {
    this.debounce.call(() => this.element.requestSubmit(this.previewButtonTarget))
  }
}
