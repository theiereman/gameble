import { preview, tickedCopies, type Copy, type EntrustState, type PreviewLine, type Selecting } from "./entrust"
import { writeText } from "./dom_writes"
import { t, type Template } from "./i18n"
import { picoins } from "./picoins"
import type { StepperView } from "./stepper"

export type EntrustStrings = {
  amount: string
  quantityLabel: string
  valueText: string
  max: string
  maxPhone: string
  submit: Template
  line: string
  count: string
  stays: Template
  overCap: Template
  rareNote: Template
  capText: string
  status: Template
  barCount: Template
  more: Template
  setApartHeading: Template
  setApartStatus: Template
  seekers: Template
  choose: Template
}

export type CellView = {
  ref: string
  ticked: boolean
  tabbable: boolean
  copies: number
  stepper: StepperView | null
}

export type GridView = {
  cells: ReadonlyMap<string, CellView>
  selecting: Selecting
  firstOfTwoSteps: boolean
}

export type TickView = { copy: Copy; copies: number }

export type LineView = {
  ref: string
  label: string
  count: string
  amount: number | null
  stays: string | null
  stepper: StepperView | null
  state: "fits" | "partial" | "stays"
}

export type SetApartLineView = { ref: string; rarity: string; label: string; seekers: string }

export type SetApartView = { heading: string; lines: readonly SetApartLineView[]; more: string | null }

export type RecapView = {
  prompt: boolean
  lines: readonly LineView[]
  setApart: SetApartView | null
  finality: boolean
  received: number
  capBefore: number
  capUsed: number
  capTotal: number
  capText: string
  full: boolean
  over: string | null
  rare: string | null
  more: string | null
  label: string
  disabled: boolean
  status: string
  bar: { count: string; amount: number }
}

export type AmountForms = { locale: string; accessible: string }

export function drawAmount(node: Element, amount: number, { locale, accessible }: AmountForms): void {
  const figure = picoins(amount, { locale })
  node.setAttribute("aria-label", t(accessible, { amount: figure }))
  writeText(node.querySelector(".picoin-amount__figure"), figure)
}

function stepperOf(strings: EntrustStrings, title: string, value: number, max: number): StepperView {
  return {
    value,
    max,
    label: t(strings.quantityLabel, { title }),
    valueText: t(strings.valueText, { count: value, max }),
    maxText: t(strings.max, { max }),
    maxPhoneText: t(strings.maxPhone, { max }),
  }
}

export function gridViewOf(state: EntrustState, strings: EntrustStrings): GridView {
  const cells = new Map<string, CellView>()
  for (const ref of state.loaded) {
    const copy = state.copies[ref]
    if (!copy) continue
    const copies = state.ticked[ref] ?? 0
    cells.set(ref, {
      ref,
      ticked: copies > 0,
      tabbable: ref === state.active,
      copies,
      stepper: copies > 0 && copy.free > 1 ? stepperOf(strings, copy.title, copies, copy.free) : null,
    })
  }
  const firstOfTwoSteps = Object.keys(state.ticked).some((ref) => (state.copies[ref]?.seekers ?? 0) > 0)
  return { cells, selecting: state.selecting, firstOfTwoSteps }
}

// What the form posts: every ticked edition, in the list's order.
export function ticksOf(state: EntrustState): TickView[] {
  return tickedCopies(state).map((copy) => ({ copy, copies: state.ticked[copy.ref] ?? 0 }))
}

// The one posted field: "ref=copies" pairs joined by commas, which no ref holds.
export function selectionOf(ticks: readonly TickView[]): string {
  return ticks.map(({ copy, copies }) => `${copy.ref}=${copies}`).join(",")
}

export function sameCell(a: CellView | undefined, b: CellView): boolean {
  if (!a) return false
  const steppers =
    a.stepper === b.stepper ||
    (a.stepper !== null &&
      b.stepper !== null &&
      a.stepper.value === b.stepper.value &&
      a.stepper.max === b.stepper.max &&
      a.stepper.label === b.stepper.label)
  return a.ticked === b.ticked && a.tabbable === b.tabbable && a.copies === b.copies && steppers
}

// The recap draws the first lines only: a selection of every edition would otherwise build thousands of rows.
export const RECAP_LINES = 30
const NAMED = 10

const names = (titles: readonly string[]): string =>
  titles.length > NAMED ? `${titles.slice(0, NAMED).join(", ")}, …` : titles.join(", ")

export function recapViewOf(
  state: EntrustState,
  strings: EntrustStrings,
  { open, locale, accessible, dailyCap }: { open: boolean; dailyCap: number } & AmountForms,
): RecapView {
  const result = preview(state)
  const mintedToday = Math.max(dailyCap - state.capLeft, 0)
  const staying = result.lines.filter((line) => line.stayed > 0)
  const status = [
    t(strings.status, { count: result.count, amount: t(accessible, { amount: picoins(result.received, { locale }) }) }),
    ...(result.setApartCount > 0 ? [t(strings.setApartStatus, { count: result.setApartCount })] : []),
  ].join(", ")
  const onlyWanted = result.count === 0 && result.setApartCount > 0
  return {
    prompt: result.lines.length === 0 && result.setApartCount === 0,
    setApart: setApartViewOf(result.setApart, result.setApartCount, strings),
    finality: !onlyWanted,
    lines: result.lines.slice(0, RECAP_LINES).map(({ copy, copies, entrusted, stayed }) => ({
      ref: copy.ref,
      label: t(strings.line, { title: copy.title, season: copy.season }),
      count: t(strings.count, { count: copies }),
      amount: entrusted > 0 ? entrusted * copy.value : null,
      stays: stayed > 0 ? t(strings.stays, { count: stayed }) : null,
      stepper: copy.free > 1 ? stepperOf(strings, copy.title, copies, copy.free) : null,
      state: stayed === 0 ? "fits" : entrusted === 0 ? "stays" : "partial",
    })),
    received: result.received,
    capBefore: mintedToday,
    capUsed: mintedToday + result.capUsed,
    capTotal: dailyCap,
    capText: t(strings.capText, {
      used: picoins(mintedToday + result.capUsed, { locale }),
      cap: picoins(dailyCap, { locale }),
    }),
    full: result.full,
    over:
      result.stayedCount > 0
        ? t(strings.overCap, { count: result.stayedCount, cards: names(staying.map((line) => line.copy.title)) })
        : null,
    rare:
      result.rareCount > 0 ? t(strings.rareNote, { count: result.rareCount, cards: names(result.rareNames) }) : null,
    more: result.lines.length > RECAP_LINES ? t(strings.more, { count: result.lines.length - RECAP_LINES }) : null,
    label: onlyWanted ? t(strings.choose, { count: result.setApartCount }) : t(strings.submit, { count: result.count }),
    disabled: !open || !result.canValidate,
    status,
    bar: { count: t(strings.barCount, { count: result.count }), amount: result.received },
  }
}

function setApartViewOf(lines: readonly PreviewLine[], count: number, strings: EntrustStrings): SetApartView | null {
  if (count === 0) return null
  return {
    heading: t(strings.setApartHeading, { count }),
    lines: lines.slice(0, RECAP_LINES).map(({ copy }) => ({
      ref: copy.ref,
      rarity: copy.rarity,
      label: t(strings.line, { title: copy.title, season: copy.season }),
      seekers: t(strings.seekers, { count: copy.seekers ?? 0 }),
    })),
    more: lines.length > RECAP_LINES ? t(strings.more, { count: lines.length - RECAP_LINES }) : null,
  }
}
