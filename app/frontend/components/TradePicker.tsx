import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react"
import { t } from "../lib/i18n"
import { RARITIES, type Rarity } from "../lib/card_types"
import { columnsOf, filterCards, gridMove, toggle, setQuantity, sideCount, type Line } from "../lib/trade_board"
import QuantityStepper from "./QuantityStepper"
import type { TradeBoardStrings, TradeSideData } from "./TradeBoard"

export type TradePickerProps = {
  side: TradeSideData
  lines: Line[]
  strings: TradeBoardStrings
  closeIcon: string
  onPlace: (lines: Line[]) => void
  onClose: () => void
}

export default function TradePicker({ side, lines, strings, closeIcon, onPlace, onClose }: TradePickerProps) {
  const dialog = useRef<HTMLDialogElement>(null)
  const grid = useRef<HTMLUListElement>(null)
  const placeButton = useRef<HTMLButtonElement>(null)
  const [selection, setSelection] = useState<Line[]>(lines)
  const [refused, setRefused] = useState(false)
  const search = useRef<HTMLInputElement>(null)
  const [query, setQuery] = useState("")
  const [rarities, setRarities] = useState<Rarity[]>([])
  const [activeKey, setActiveKey] = useState<string | null>(() => (lines.length > 0 ? lines[0].key : null))
  const closed = useRef(onClose)
  closed.current = onClose
  const closeHtml = useMemo(() => ({ __html: closeIcon }), [closeIcon])

  useEffect(() => {
    const element = dialog.current
    if (!element) return
    const onClosed = () => closed.current()
    element.addEventListener("close", onClosed)
    if (!element.open && typeof element.showModal === "function") element.showModal()
    const first = grid.current?.querySelector<HTMLButtonElement>('.trade-pick__toggle[tabindex="0"]') ?? placeButton.current
    first?.focus()
    return () => {
      element.removeEventListener("close", onClosed)
      if (element.open) element.close()
    }
  }, [])

  const shut = () => {
    if (dialog.current?.open) dialog.current.close()
  }

  const visible = useMemo(() => filterCards(side.cards, query, rarities), [side.cards, query, rarities])
  const filtering = query.trim() !== "" || rarities.length > 0
  const found = activeKey === null ? -1 : visible.findIndex((card) => card.key === activeKey)
  const active = Math.max(0, found)

  const toggleRarity = (rarity: Rarity) =>
    setRarities((current) => (current.includes(rarity) ? current.filter((value) => value !== rarity) : [...current, rarity]))

  const clearFilters = () => {
    setQuery("")
    setRarities([])
    search.current?.focus()
  }

  const pick = (key: string) => {
    const card = side.cards.find((candidate) => candidate.key === key)
    if (!card) return
    setActiveKey(key)
    const next = toggle(selection, card.key, card.max)
    setRefused(next.refused)
    setSelection(next.lines)
  }

  const onGridKeyDown = (event: KeyboardEvent<HTMLUListElement>) => {
    const target = event.target as HTMLElement
    if (!target.classList.contains("trade-pick__toggle") || !grid.current) return
    const items = Array.from(grid.current.querySelectorAll<HTMLElement>(":scope > .trade-pick"))
    const columns = columnsOf(items.map((item) => item.offsetTop))
    const next = gridMove(active, event.key, visible.length, columns)
    if (next === null) return
    event.preventDefault()
    setActiveKey(visible[next]?.key ?? null)
    items[next]?.querySelector<HTMLButtonElement>(".trade-pick__toggle")?.focus()
  }

  const count = sideCount(selection)
  const nothingToPlace =
    side.cards.length === 0 ? side.none : side.cards.every((card) => card.max < 1) ? strings.noneAllReserved : null
  const picked = new Map(selection.map((line) => [line.key, line.quantity]))

  return (
    <dialog
      ref={dialog}
      className="modal modal--wide trade-picker"
      aria-labelledby="trade-picker-title"
      onClick={(event) => {
        // A click on the dialog element itself lands on its backdrop.
        if (event.target === event.currentTarget) shut()
      }}
    >
      <div className="panel panel--brackets modal__panel trade-picker__panel">
        <span className="modal__handle" aria-hidden="true" />
        <div className="modal__head">
          <h2 id="trade-picker-title" className="modal__title">
            <span className="trade-picker__title">{side.pickerTitle}</span>
            <span className="trade-picker__title-short">{side.pickerTitleShort}</span>
          </h2>
          <button type="button" className="modal__close" aria-label={strings.close} onClick={shut} dangerouslySetInnerHTML={closeHtml} />
        </div>
        <p className="trade-picker__note">{side.note}</p>
        {side.cards.length > 0 && (
          <div className="trade-picker__filters" role="search">
            <label className="visually-hidden" htmlFor="trade-picker-search">
              {strings.searchLabel}
            </label>
            <input
              ref={search}
              id="trade-picker-search"
              type="search"
              className="filters__search-field"
              value={query}
              autoComplete="off"
              placeholder={strings.searchPlaceholder}
              onChange={(event) => setQuery(event.target.value)}
            />
            <fieldset className="filters__group trade-picker__rarities">
              <legend className="filters__legend">{strings.raritiesLegend}</legend>
              {RARITIES.map((rarity) => (
                <label key={rarity} className="filter-chip">
                  <input
                    type="checkbox"
                    className="filter-chip__box"
                    checked={rarities.includes(rarity)}
                    onChange={() => toggleRarity(rarity)}
                  />
                  <span className="filter-chip__text">{strings.rarities[rarity]}</span>
                </label>
              ))}
            </fieldset>
            <div className="trade-picker__filter-foot">
              <p className="trade-picker__results" aria-live="polite">
                {t(strings.results, { count: visible.length })}
              </p>
              {filtering && (
                <button type="button" className="filters__clear trade-picker__clear" onClick={clearFilters}>
                  {strings.clearFilters}
                </button>
              )}
            </div>
          </div>
        )}
        <div className="trade-picker__body">
          {nothingToPlace && (
            <p className="trade-picker__empty">
              <b className="trade-picker__empty-title">{strings.noneTitle}</b> {nothingToPlace}
            </p>
          )}
          {side.cards.length > 0 && !nothingToPlace && visible.length === 0 && <p className="trade-picker__empty">{strings.noMatch}</p>}
          {visible.length > 0 && (
            <ul ref={grid} className="trade-picker__grid" aria-labelledby="trade-picker-title" onKeyDown={onGridKeyDown}>
              {visible.map((card, index) => {
                const quantity = picked.get(card.key)
                const isPicked = quantity !== undefined
                const unavailable = card.max < 1
                const label = [
                  t(strings.cardLabel, { title: card.title, owned: t(strings.owned, { count: card.owned }) }),
                  card.reserved > 0 ? t(strings.reservedElsewhere, { count: card.reserved }) : null,
                  unavailable ? strings.unavailable : null,
                ]
                  .filter(Boolean)
                  .join(", ")
                return (
                  <li key={card.key} className="trade-pick">
                    <div
                      className={[
                        "trade-pick__card",
                        isPicked ? "trade-pick__card--picked" : null,
                        unavailable ? "trade-pick__card--unavailable" : null,
                      ]
                        .filter(Boolean)
                        .join(" ")}
                    >
                      <div className="trade-pick__face" aria-hidden="true" dangerouslySetInnerHTML={{ __html: card.face }} />
                      <span className="trade-pick__owned" aria-hidden="true">
                        ×{card.owned}
                      </span>
                      {card.reserved > 0 && (
                        <span className="trade-card__reserved trade-pick__reserved" aria-hidden="true">
                          {t(strings.reserved, { count: unavailable ? 1 : card.reserved })}
                        </span>
                      )}
                      {isPicked && (
                        <span className="trade-pick__check" aria-hidden="true">
                          ✓
                        </span>
                      )}
                      <button
                        type="button"
                        className="trade-pick__toggle"
                        tabIndex={index === active ? 0 : -1}
                        aria-pressed={isPicked}
                        aria-disabled={unavailable && !isPicked ? true : undefined}
                        aria-label={label}
                        onClick={() => pick(card.key)}
                      />
                    </div>
                    <div className="trade-pick__foot">
                      {isPicked && card.max > 1 ? (
                        <QuantityStepper
                          value={quantity}
                          max={card.max}
                          label={t(strings.quantity, { title: card.title })}
                          valueText={t(strings.valueText, { count: quantity, max: card.max })}
                          maxText={t(strings.max, { max: card.max })}
                          maxPhoneText={t(strings.maxPhone, { max: card.max })}
                          more={strings.more}
                          fewer={strings.fewer}
                          onChange={(value) => setSelection((current) => setQuantity(current, card.key, value, card.max))}
                        />
                      ) : (
                        <span className="trade-pick__available">{t(strings.available, { count: Math.max(0, card.max) })}</span>
                      )}
                    </div>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
        <p className="trade-picker__refusal" role="alert">
          {refused && (
            <>
              <b>{strings.limitTitle}</b> · {strings.limitText}
            </>
          )}
        </p>
        <div className="trade-picker__actions">
          <p className="trade-picker__count" aria-live="polite">
            {t(strings.picked, {
              cards: t(strings.pickedCards, { count: count.cards }),
              copies: t(strings.pickedCopies, { count: count.copies }),
            })}
          </p>
          <button
            ref={placeButton}
            type="button"
            className="button button--primary"
            onClick={() => {
              onPlace(selection)
              shut()
            }}
          >
            {strings.place}
          </button>
          <button type="button" className="button button--secondary" onClick={shut}>
            {strings.cancel}
          </button>
        </div>
      </div>
    </dialog>
  )
}
