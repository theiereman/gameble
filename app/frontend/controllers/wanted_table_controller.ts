import { Controller } from "@hotwired/stimulus"
import { writeChecked, writeDisabled, writeHidden, writeText, writeValue } from "../lib/dom_writes"
import { t, type Template } from "../lib/i18n"
import { picoins } from "../lib/picoins"
import {
  choose,
  pending,
  prefill,
  setDuration,
  setStart,
  start,
  totals,
  type Choice,
  type Picked,
  type WantedLine,
  type WantedTableState,
} from "../lib/wanted_table"
import type WantedDockController from "./wanted_dock_controller"

export type WantedStrings = {
  amount: string
  changedTo: string
  choiceOrder: string
  choiceAuction: string
  choiceEntrust: string
  sales: Template
  entrusted: Template
  listed: Template
  allEntrust: string
  status: string
  overCap: Template
}

const CHOICES: readonly Choice[] = ["order", "auction", "entrust"]

function lineFrom(element: HTMLElement): WantedLine {
  const data = element.dataset
  return {
    ref: data.ref ?? "",
    title: data.title ?? "",
    copies: Number(data.copies),
    value: Number(data.value),
    minimum: Number(data.minimum),
    stamp: Number(data.stamp),
    average: data.average ? Number(data.average) : null,
    orders: (data.orders ?? "").split(",").filter(Boolean).map(Number),
    direct: data.direct === "true",
    changed: data.changed === "true",
  }
}

function choiceInputs(line: HTMLElement): HTMLInputElement[] {
  return Array.from(line.querySelectorAll<HTMLInputElement>('input[type="radio"][name$="[choice]"]'))
}

function pickedFrom(line: HTMLElement): Picked {
  const checked = choiceInputs(line).find((input) => input.checked)?.value
  const duration =
    line.querySelector<HTMLInputElement>('input[type="radio"][name$="[duration_hours]"]:checked')?.value ?? ""
  return {
    choice: CHOICES.find((choice) => choice === checked) ?? null,
    start: line.querySelector<HTMLInputElement>('input[name$="[starting_price]"]')?.value ?? "",
    duration,
  }
}

export default class WantedTableController extends Controller<HTMLFormElement> {
  static targets = ["line"]
  static values = {
    locale: String,
    capLeft: Number,
    available: Number,
    basisPoints: Number,
    strings: Object,
    focus: String,
  }
  static outlets = ["wanted-dock"]

  declare readonly lineTargets: HTMLElement[]
  declare readonly localeValue: string
  declare readonly capLeftValue: number
  declare readonly availableValue: number
  declare readonly basisPointsValue: number
  declare readonly stringsValue: WantedStrings
  declare readonly focusValue: string
  declare readonly hasWantedDockOutlet: boolean
  declare readonly wantedDockOutlet: WantedDockController

  private state?: WantedTableState
  private submitting = false

  // Esc here closes an overlay and nothing else: it never drops the choices nor leaves the screen.
  private readonly guardEscape = (event: KeyboardEvent): void => {
    if (
      event.key !== "Escape" ||
      !this.state ||
      document.querySelector("dialog[open], [popover]:not([popover=manual]):popover-open") ||
      !pending(this.state)
    )
      return
    event.preventDefault()
    event.stopPropagation()
  }

  connect(): void {
    const lines = this.lineTargets.map(lineFrom)
    const picked = Object.fromEntries(this.lineTargets.map((line) => [line.dataset.ref ?? "", pickedFrom(line)]))
    this.state = prefill(
      start(lines, picked, {
        capLeft: this.capLeftValue,
        basisPoints: this.basisPointsValue,
        available: this.availableValue,
      }),
    )
    document.addEventListener("keydown", this.guardEscape, true)
    this.render(true)
    this.focusOnArrival()
  }

  disconnect(): void {
    document.removeEventListener("keydown", this.guardEscape, true)
    this.state = undefined
  }

  wantedDockOutletConnected(): void {
    this.render()
  }

  choose(event: Event): void {
    const input = event.target as HTMLInputElement
    const choice = CHOICES.find((each) => each === input.value)
    const ref = this.refOf(input)
    if (this.state && choice && ref) this.apply(choose(this.state, ref, choice))
  }

  typeStart(event: Event): void {
    const input = event.target as HTMLInputElement
    const ref = this.refOf(input)
    if (this.state && ref) this.apply(setStart(this.state, ref, input.value))
  }

  pickDuration(event: Event): void {
    const input = event.target as HTMLInputElement
    const ref = this.refOf(input)
    if (this.state && ref) this.apply(setDuration(this.state, ref, input.value))
  }

  // Enter in a field never submits: the form's first submit button entrusts every line.
  holdEnter(event: KeyboardEvent): void {
    if (event.target instanceof HTMLInputElement) event.preventDefault()
  }

  // A double activation submits once.
  submit(event: SubmitEvent): void {
    if (this.submitting) event.preventDefault()
    this.submitting = true
  }

  released(): void {
    this.submitting = false
  }

  private apply(next: WantedTableState): void {
    if (next === this.state) return
    this.state = next
    this.render()
  }

  private refOf(input: Element): string | undefined {
    return input.closest<HTMLElement>("[data-wanted-table-target~='line']")?.dataset.ref
  }

  private render(drawing = false): void {
    const state = this.state
    if (!state) return
    const sums = totals(state)
    for (const line of this.lineTargets) {
      const ref = line.dataset.ref ?? ""
      const picked = state.picked[ref]
      if (!picked) continue
      this.reflectLine(line, picked, drawing)
    }
    if (this.hasWantedDockOutlet) this.wantedDockOutlet.render(sums, this.stringsValue)
  }

  private reflectLine(line: HTMLElement, picked: Picked, drawing: boolean): void {
    for (const input of choiceInputs(line)) writeChecked(input, input.value === picked.choice)
    const auction = picked.choice === "auction"
    const fields = line.querySelector<HTMLElement>("[data-wanted-table-target~='auction']")
    writeHidden(fields, !auction)
    fields?.querySelectorAll<HTMLInputElement>("input").forEach((input) => writeDisabled(input, !auction))
    const startField = line.querySelector<HTMLInputElement>("[data-wanted-table-target~='start']")
    if (drawing && startField && startField.value.trim() === "" && picked.start !== "")
      writeValue(startField, picoins(Number(picked.start), { locale: this.localeValue }))
    if (drawing && line.dataset.changed === "true" && picked.choice !== null)
      writeText(
        line.querySelector(".wanted-line__changed-to"),
        t(this.stringsValue.changedTo, { choice: this.choiceName(picked.choice) }),
      )
  }

  private choiceName(choice: Choice): string {
    const strings = this.stringsValue
    return choice === "order"
      ? strings.choiceOrder
      : choice === "auction"
        ? strings.choiceAuction
        : strings.choiceEntrust
  }

  // On arrival the heading takes focus; after a refusal, the first changed group or invalid field the server named.
  private focusOnArrival(): void {
    const target = this.focusValue ? document.getElementById(this.focusValue) : null
    if (!target) return
    const focusable = target.matches("input, button, [tabindex]")
      ? target
      : (target.querySelector<HTMLElement>("input:checked:not(:disabled)") ??
        target.querySelector<HTMLElement>("input:not(:disabled)"))
    focusable?.focus({ preventScroll: false })
  }
}
