// The trade board island (AD-16; DESIGN.md, Trade board, Stack, Quantity
// stepper, Add slot; EXPERIENCE.md, Échanges, Focus after each step; story
// 5.7), mounted on the counter-proposal's board inside its server form. It
// draws both sides "EN ÉDITION", the friend's first, with the status line
// between them: each card at card-s (the size of the add slot beside it),
// with its stepper when more than one copy may be placed and "✕"; an add
// slot while a side holds fewer than four cards opens the card picker
// (TradePicker). Each side writes its fields (`give[<key>]`, `take[<key>]`)
// for the form, and every change goes to the page as `gameble:trade-changed`
// (the send button waits for a card on each side). The faces come from the
// server (CardComponent); the words from the locale files, through props.
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import { flushSync } from "react-dom"
import { dispatchGameble } from "../lib/events"
import { t, type Template } from "../lib/i18n"
import { MAX_CARDS, initialLines, remove, setQuantity, sideCount, type Line } from "../lib/trade_board"
import QuantityStepper from "./QuantityStepper"
import TradePicker from "./TradePicker"

/** A card its holder holds: the player's own (with copies reserved elsewhere) or the friend's. */
export type TradeCard = {
  key: string
  title: string
  owned: number
  reserved: number
  /** The copies that may be placed: the player's free copies, or what the friend holds. */
  max: number
  /** The card-s face, rendered on the server. */
  face: string
}

export type TradeSideData = {
  side: "friend" | "own"
  field: "take" | "give"
  label: string
  add: string
  pickerTitle: string
  pickerTitleShort: string
  note: string
  cards: TradeCard[]
  lines: Line[]
}

export type TradeBoardStrings = {
  close: string
  place: string
  cancel: string
  remove: string
  more: string
  fewer: string
  valueText: string
  maxPhone: string
  available: Template
  picked: string
  pickedCards: Template
  pickedCopies: Template
  limitTitle: string
  limitText: string
  empty: string
  cardLabel: string
  owned: Template
  reservedElsewhere: Template
  unavailable: string
  editing: string
  cards: Template
  cardsCopies: Template
  copiesLabel: string
  reserved: Template
  quantity: string
  max: string
}

export type TradeBoardProps = {
  sides: TradeSideData[]
  message: string
  error: string | null
  swapIcon: string
  closeIcon: string
  strings: TradeBoardStrings
}

// Where the focus goes after the next render: a side's card (its "✕"), or its add slot;
// `preventScroll` when the board opens.
type FocusTarget = { side: number; key: string | null; preventScroll?: boolean }

export default function TradeBoard({ sides, message, error, swapIcon, closeIcon, strings }: TradeBoardProps) {
  const cardsBySide = useMemo(() => sides.map((side) => new Map(side.cards.map((card) => [card.key, card]))), [sides])
  const [lines, setLines] = useState<Line[][]>(() =>
    sides.map((side, index) => initialLines(side.lines, new Map(Array.from(cardsBySide[index].values(), (card) => [card.key, card.max])))),
  )
  const [picking, setPicking] = useState<number | null>(null)
  const sideElements = useRef<(HTMLDivElement | null)[]>([])
  // The board opens for a counter-proposal: the focus goes to the add slot on the
  // player's side (EXPERIENCE.md, Focus after each step: "CONTRE-PROPOSER"), the page
  // left where it is.
  const focusAfter = useRef<FocusTarget | null>({ side: sides.findIndex((side) => side.side === "own"), key: null, preventScroll: true })
  const swapHtml = useMemo(() => ({ __html: swapIcon }), [swapIcon])
  const closeHtml = useMemo(() => ({ __html: closeIcon }), [closeIcon])

  // The page's send button follows the sides.
  useEffect(() => {
    const count = (field: TradeSideData["field"]) => sideCount(lines[sides.findIndex((side) => side.field === field)] ?? [])
    dispatchGameble("gameble:trade-changed", { give: count("give"), take: count("take") })
  }, [lines, sides])

  // A page kept by Turbo never shows the picker open: closed before the snapshot is taken.
  useEffect(() => {
    const beforeCache = () => flushSync(() => setPicking(null))
    document.addEventListener("turbo:before-cache", beforeCache)
    return () => document.removeEventListener("turbo:before-cache", beforeCache)
  }, [])

  useLayoutEffect(() => {
    const target = focusAfter.current
    if (!target) return
    focusAfter.current = null
    const element = sideElements.current[target.side]
    if (!element) return
    const card = target.key === null ? null : element.querySelector<HTMLElement>(`[data-remove="${CSS.escape(target.key)}"]`)
    const fallback = element.querySelector<HTMLElement>(".trade-add") ?? element.querySelector<HTMLElement>(".trade-card__remove")
    ;(card ?? fallback)?.focus({ preventScroll: target.preventScroll ?? false })
  })

  const update = (index: number, next: Line[]) => setLines((current) => current.map((side, at) => (at === index ? next : side)))

  // "✕": the next card on that side takes the focus, or its add slot.
  const removeCard = (index: number, key: string) => {
    const side = lines[index]
    const at = side.findIndex((line) => line.key === key)
    focusAfter.current = { side: index, key: side[at + 1]?.key ?? null }
    update(index, remove(side, key))
  }

  const countText = (side: Line[]) => {
    const { cards, copies } = sideCount(side)
    const cardsText = t(strings.cards, { count: cards })
    return copies === cards ? cardsText : t(strings.cardsCopies, { count: cards, cards: cardsText, copies })
  }

  const renderSide = (side: TradeSideData, index: number) => {
    const sideLines = lines[index]
    const cards = cardsBySide[index]
    return (
      <div
        key={side.side}
        ref={(element) => {
          sideElements.current[index] = element
        }}
        className={`trade-side trade-side--${side.side} trade-side--editing`}
      >
        <p className="trade-side__header">
          <span className="trade-side__label">{side.label}</span>
          <span className="trade-side__editing">{strings.editing}</span>
          <span className="trade-side__count">{countText(sideLines)}</span>
        </p>
        <ul className="trade-side__cards">
          {sideLines.map((line) => {
            const card = cards.get(line.key)
            if (!card) return null
            return (
              <li key={line.key} className={["trade-card", "trade-card--editing", line.quantity > 1 ? "trade-card--stack" : null].filter(Boolean).join(" ")}>
                <div className="trade-card__face" dangerouslySetInnerHTML={{ __html: card.face }} />
                {card.max > 1 ? (
                  <QuantityStepper
                    value={line.quantity}
                    max={card.max}
                    label={t(strings.quantity, { title: card.title })}
                    valueText={t(strings.valueText, { count: line.quantity, max: card.max })}
                    maxText={t(strings.max, { max: card.max })}
                    maxPhoneText={t(strings.maxPhone, { max: card.max })}
                    more={strings.more}
                    fewer={strings.fewer}
                    onChange={(value) => update(index, setQuantity(sideLines, line.key, value, card.max))}
                  />
                ) : null}
                <button
                  type="button"
                  className="trade-card__remove"
                  data-remove={line.key}
                  aria-label={t(strings.remove, { title: card.title })}
                  onClick={() => removeCard(index, line.key)}
                  dangerouslySetInnerHTML={closeHtml}
                />
                <input type="hidden" name={`${side.field}[${line.key}]`} value={line.quantity} />
              </li>
            )
          })}
          {sideLines.length < MAX_CARDS && (
            <li className="trade-card">
              <button type="button" className="trade-add" aria-haspopup="dialog" onClick={() => setPicking(index)}>
                <span className="trade-add__plus" aria-hidden="true">
                  +
                </span>
                <span className="trade-add__label">{side.add}</span>
              </button>
            </li>
          )}
        </ul>
      </div>
    )
  }

  const friend = sides.findIndex((side) => side.side === "friend")
  const own = sides.findIndex((side) => side.side === "own")

  return (
    <>
      {friend >= 0 && renderSide(sides[friend], friend)}
      <div className="trade-board__middle">
        <span className="trade-board__swap-box" aria-hidden="true" dangerouslySetInnerHTML={swapHtml} />
        <p className="trade-board__message">{message}</p>
        {error && (
          <p className="trade-board__error" role="alert">
            {error}
          </p>
        )}
      </div>
      {own >= 0 && renderSide(sides[own], own)}
      {picking !== null && (
        <TradePicker
          side={sides[picking]}
          lines={lines[picking]}
          strings={strings}
          closeIcon={closeIcon}
          onPlace={(next) => update(picking, next)}
          onClose={() => {
            // Back to the add slot that opened it, or the side's first card once it holds four.
            focusAfter.current = { side: picking, key: null }
            setPicking(null)
          }}
        />
      )}
    </>
  )
}
