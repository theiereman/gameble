import { chosenEdition, lines, type Field, type ListingState, type Refusal } from "./listing_form"
import { t } from "./i18n"
import { picoins } from "./picoins"

export type ListingStrings = {
  amount: string
  invalidPrice: string
  minimumHint: string
  minimumRefusal: string
  status: string
  step: string
}

export type Forms = { locale: string; strings: ListingStrings }

export type CellView = { ref: string; chosen: boolean; tabbable: boolean }

export type GridView = { cells: readonly CellView[]; chosen: string }

export type FieldView = { error: string | null }

export type FieldsView = {
  chosen: string
  hint: string
  start: FieldView
  duration: string
  locked: boolean
}

export type SummaryView = {
  stamp: number | null
  commission: number | null
  received: number | null
  disabled: boolean
  status: string
}

export function gridViewOf(state: ListingState): GridView {
  const tabbable = state.chosen ?? state.editions[0]?.ref
  return {
    cells: state.editions.map((edition) => ({
      ref: edition.ref,
      chosen: edition.ref === state.chosen,
      tabbable: edition.ref === tabbable,
    })),
    chosen: state.chosen ?? "",
  }
}

export function refusalText(refusal: Refusal, state: ListingState, { locale, strings }: Forms): string {
  const edition = chosenEdition(state)
  if (refusal.code === "invalidPrice") return strings.invalidPrice
  return t(strings.minimumRefusal, {
    amount: picoins(edition?.minimum ?? 0, { locale }),
    rarity: edition?.rarityName ?? "",
  })
}

function fieldView(field: Field, state: ListingState, forms: Forms): FieldView {
  const shown = state.shown
  return { error: shown && shown.field === field ? refusalText(shown, state, forms) : null }
}

export function fieldsViewOf(state: ListingState, forms: Forms): FieldsView {
  const edition = chosenEdition(state)
  return {
    chosen: edition?.ref ?? "",
    hint: edition
      ? t(forms.strings.minimumHint, {
          amount: picoins(edition.minimum, { locale: forms.locale }),
          rarity: edition.rarityName,
        })
      : "",
    start: fieldView("start", state, forms),
    duration: state.duration,
    locked: edition === null,
  }
}

export function statusOf(figure: number | null, { locale, strings }: Forms): string {
  return figure === null ? "" : t(strings.status, { amount: picoins(figure, { locale }) })
}

export function summaryViewOf(state: ListingState, forms: Forms, open: boolean): SummaryView {
  const shown = lines(state)
  return {
    stamp: shown?.stamp ?? null,
    commission: shown?.commission ?? null,
    received: shown?.received ?? null,
    disabled: !open || shown === null,
    status: statusOf(shown?.received ?? null, forms),
  }
}

export function stepText(state: ListingState, { strings }: Forms): string {
  return t(strings.step, { step: state.step })
}
