import type { PickView, PickerScreen } from "../controllers/trade_board_picker_controller"
import type { SideView } from "../controllers/trade_board_side_controller"
import { t, type Template } from "./i18n"
import type { StepperView } from "./stepper"
import { MAX_CARDS, cardOf, pickerView, showsOpenHelp, sideCount, type BoardState, type Line, type Side, type TradeCard } from "./trade_board"

export type BoardStrings = {
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

function stepperView(strings: BoardStrings, card: TradeCard, value: number): StepperView {
  return {
    value,
    max: card.max,
    label: t(strings.quantityLabel, { title: card.title }),
    valueText: t(strings.valueText, { count: value, max: card.max }),
    maxText: t(strings.max, { max: card.max }),
    maxPhoneText: t(strings.maxPhone, { max: card.max }),
  }
}

function countText(strings: BoardStrings, lines: readonly Line[]): string {
  const { cards, copies } = sideCount(lines)
  const cardsText = t(strings.cards, { count: cards })
  return copies === cards ? cardsText : t(strings.cardsCopies, { count: cards, cards: cardsText, copies })
}

export function sideViewOf(state: BoardState, side: Side, strings: BoardStrings): SideView {
  const lines = state.lines[side]
  return {
    lines: lines.flatMap((line) => {
      const card = cardOf(state, side, line.key)
      if (!card) return []
      return [
        {
          key: line.key,
          quantity: line.quantity,
          removeLabel: t(strings.remove, { title: card.title }),
          stepper: card.max > 1 ? stepperView(strings, card, line.quantity) : null,
        },
      ]
    }),
    count: countText(strings, lines),
    canAdd: lines.length < MAX_CARDS,
    help: showsOpenHelp(side, lines),
  }
}

export function pickerScreenOf(state: BoardState, strings: BoardStrings): PickerScreen | null {
  const view = pickerView(state)
  if (!view) return null
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
        stepper: pressed && card.max > 1 ? stepperView(strings, card, quantity) : null,
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
