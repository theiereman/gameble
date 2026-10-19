import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import { flushSync } from "react-dom"
import { dispatchGameble, onGameble } from "../lib/events"
import { t, type Template } from "../lib/i18n"
import type { Rarity } from "../lib/card_types"
import {
  MAX_CARDS,
  freshPickerFilters,
  initialLines,
  remove,
  replacePickerFilters,
  setQuantity,
  showsOpenHelp,
  sideCount,
  type ChipLabels,
  type Line,
  type PickerFilters,
  type Side,
} from "../lib/trade_board"
import { forgetDraft, readDraft, sameLines, saveDraft, type DraftSides } from "../lib/trade_draft"
import { batches, facesFrom, facesUrl, missingFaces, withFaces, type Faces } from "../lib/trade_faces"
import QuantityStepper from "./QuantityStepper"
import TradePicker from "./TradePicker"

export type TradeCard = {
  key: string
  title: string
  rarity: Rarity
  owned: number
  reserved: number
  max: number
  copies: number
  otherCopies: number
}

export type TradeSideData = {
  side: Side
  field: "take" | "give"
  label: string
  readHtml: string | null
  help: string | null
  add: string
  pickerTitle: string
  pickerTitleShort: string
  note: string
  none: string
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
  noneTitle: string
  noneAllReserved: string
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
  searchLabel: string
  searchPlaceholder: string
  raritiesLegend: string
  rarities: Record<Rarity, string>
  compareLegend: string
  chips: ChipLabels
  clearFilters: string
  filtersTitle: string
  filtersActive: string
  noMatch: string
  results: Template
}

export type TradeBoardProps = {
  sides: TradeSideData[]
  message: string
  readMessage: string | null
  editing: boolean
  draftKey: string
  formId: string
  error: string | null
  faces: Record<string, string>
  facesUrl: string
  facesBatch: number
  swapIcon: string
  closeIcon: string
  chevronIcon: string
  strings: TradeBoardStrings
}

type FocusTarget = { side: number; key: string | null; preventScroll?: boolean }

const maximaOf = (side: TradeSideData) => new Map(side.cards.map((card) => [card.key, card.max]))

export default function TradeBoard(props: TradeBoardProps) {
  const { sides, message, readMessage, draftKey, formId, error, swapIcon, closeIcon, chevronIcon, strings } = props
  const cardsBySide = useMemo(() => sides.map((side) => new Map(side.cards.map((card) => [card.key, card]))), [sides])
  const received = useMemo(() => sides.map((side) => initialLines(side.lines, maximaOf(side))), [sides])
  const [editing, setEditing] = useState(props.editing)
  const [lines, setLines] = useState<Line[][]>(() => {
    const kept = readDraft(draftKey)
    return kept ? sides.map((side) => initialLines(kept[side.field] ?? [], maximaOf(side))) : received
  })
  const [picking, setPicking] = useState<number | null>(null)
  const [pickerFilters, setPickerFilters] = useState<PickerFilters[]>(() => freshPickerFilters(sides.length))
  const sideElements = useRef<(HTMLDivElement | null)[]>([])
  const own = sides.findIndex((side) => side.side === "own")
  const friend = sides.findIndex((side) => side.side === "friend")
  const focusAfter = useRef<FocusTarget | null>(props.editing && readMessage !== null ? { side: own, key: null, preventScroll: true } : null)
  const swapHtml = useMemo(() => ({ __html: swapIcon }), [swapIcon])
  const closeHtml = useMemo(() => ({ __html: closeIcon }), [closeIcon])
  const [faces, setFaces] = useState<Faces>(() => new Map(Object.entries(props.faces)))
  const knownFaces = useRef(faces)
  const pendingFaces = useRef(new Set<string>())
  const { facesUrl: facesBase, facesBatch } = props

  const requestFaces = useCallback(
    (keys: readonly string[]) => {
      for (const batch of batches(missingFaces(keys, knownFaces.current, pendingFaces.current), facesBatch)) {
        batch.forEach((key) => pendingFaces.current.add(key))
        fetch(facesUrl(facesBase, batch), { headers: { Accept: "application/json" }, credentials: "same-origin" })
          .then((response) => (response.ok ? response.json() : null))
          .then((body) => {
            knownFaces.current = withFaces(knownFaces.current, facesFrom(body))
            setFaces(knownFaces.current)
          })
          .catch(() => undefined)
          .finally(() => batch.forEach((key) => pendingFaces.current.delete(key)))
      }
    },
    [facesBase, facesBatch],
  )

  useEffect(() => requestFaces(lines.flatMap((side) => side.map((line) => line.key))), [lines, requestFaces])

  useEffect(() => {
    const changed = lines.some((side, index) => !sameLines(side, received[index] ?? []))
    if (changed) {
      const kept: DraftSides = {}
      sides.forEach((side, index) => (kept[side.field] = lines[index]))
      saveDraft(draftKey, kept)
    } else {
      forgetDraft(draftKey)
    }
    const count = (field: TradeSideData["field"]) => sideCount(lines[sides.findIndex((side) => side.field === field)] ?? [])
    dispatchGameble("gameble:trade-changed", { give: count("give"), take: count("take"), changed })
  }, [lines, sides, received, draftKey])

  useEffect(
    () =>
      onGameble("gameble:trade-editing", ({ editing: next }) => {
        setPicking(null)
        setEditing(next)
        if (next) focusAfter.current = { side: own, key: null }
        else setLines(received)
      }),
    [own, received],
  )

  useEffect(() => {
    // Turbo snapshots the page right after this event, before React would re-render.
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
    if (!editing) return <div key={side.side} className="trade-island__static" dangerouslySetInnerHTML={{ __html: side.readHtml ?? "" }} />
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
                <div
                  className={faces.has(line.key) ? "trade-card__face" : "trade-card__face trade-card__face--pending"}
                  dangerouslySetInnerHTML={{ __html: faces.get(line.key) ?? "" }}
                />
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
                <input type="hidden" form={formId} name={`${side.field}[${line.key}]`} value={line.quantity} />
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
        {side.help && showsOpenHelp(side.side, sideLines) && <p className="trade-side__help">{side.help}</p>}
      </div>
    )
  }

  return (
    <>
      {friend >= 0 && renderSide(sides[friend], friend)}
      <div className="trade-board__middle">
        <span className="trade-board__swap-box" aria-hidden="true" dangerouslySetInnerHTML={swapHtml} />
        <p className="trade-board__message" tabIndex={-1}>
          {editing ? message : (readMessage ?? message)}
        </p>
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
          chevronIcon={chevronIcon}
          faces={faces}
          onFacesNeeded={requestFaces}
          filters={pickerFilters[picking]}
          onFilters={(next) => setPickerFilters((all) => replacePickerFilters(all, picking, next))}
          onPlace={(next) => update(picking, next)}
          onClose={() => {
            focusAfter.current = { side: picking, key: null }
            setPicking(null)
          }}
        />
      )}
    </>
  )
}
