import { chosenEdition, lines, type Field, type ListingState, type Refusal } from "./listing_form"
import { t } from "./i18n"
import { picoins } from "./picoins"

export type ListingStrings = {
  amount: string
  invalidPrice: string
  minimumHint: string
  minimumRefusal: string
  orderWaiting: string
  stampShort: string
  status: string
  step: string
}

export type Forms = { locale: string; strings: ListingStrings }

export type CellView = { ref: string; chosen: boolean; tabbable: boolean }

export type GridView = { cells: readonly CellView[] }

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
  primary: boolean
  shortfall: string | null
  status: string
}

export function gridViewOf(state: ListingState): GridView {
  const tabbable = state.chosen !== null && state.loaded.includes(state.chosen) ? state.chosen : state.loaded[0]
  return {
    cells: state.loaded.map((ref) => ({ ref, chosen: ref === state.chosen, tabbable: ref === tabbable })),
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

export type Wallet = { open: boolean; available: number }

// An order waiting for the chosen edition is said before what the auction would bring.
function choiceStatus(state: ListingState, forms: Forms, received: number | null): string {
  const order = chosenEdition(state)?.order ?? null
  const waiting =
    order === null ? "" : t(forms.strings.orderWaiting, { amount: picoins(order, { locale: forms.locale }) })
  return [waiting, statusOf(received, forms)].filter((text) => text !== "").join(". ")
}

export function summaryViewOf(state: ListingState, forms: Forms, { open, available }: Wallet): SummaryView {
  const shown = lines(state)
  const missing = shown && shown.stamp > available ? shown.stamp - available : null
  return {
    stamp: shown?.stamp ?? null,
    commission: shown?.commission ?? null,
    received: shown?.received ?? null,
    disabled: !open || shown === null || missing !== null,
    primary: (chosenEdition(state)?.order ?? null) === null,
    shortfall:
      missing === null ? null : t(forms.strings.stampShort, { amount: picoins(missing, { locale: forms.locale }) }),
    status: choiceStatus(state, forms, shown?.received ?? null),
  }
}

export function stepText(state: ListingState, { strings }: Forms): string {
  return t(strings.step, { step: state.step })
}
