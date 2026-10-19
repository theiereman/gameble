import { memo, useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type KeyboardEvent } from "react"
import { t } from "../lib/i18n"
import { RARITIES } from "../lib/card_types"
import {
  activeChips,
  clearedFilters,
  columnsOf,
  filterCards,
  filtering,
  gridMove,
  labelledChips,
  toggle,
  toggled,
  toggledFold,
  setQuantity,
  sideCount,
  withFilter,
  type Line,
  type PickerFilters,
  type SideFilter,
} from "../lib/trade_board"
import { PICKER_PAGE, nextPage, shownFor, type Faces } from "../lib/trade_faces"
import QuantityStepper from "./QuantityStepper"
import type { TradeBoardStrings, TradeCard, TradeSideData } from "./TradeBoard"

export type TradePickerProps = {
  side: TradeSideData
  lines: Line[]
  strings: TradeBoardStrings
  closeIcon: string
  chevronIcon: string
  faces: Faces
  onFacesNeeded: (keys: readonly string[]) => void
  filters: PickerFilters
  onFilters: (next: PickerFilters) => void
  onPlace: (lines: Line[]) => void
  onClose: () => void
}

export default function TradePicker({
  side,
  lines,
  strings,
  closeIcon,
  chevronIcon,
  faces,
  onFacesNeeded,
  filters,
  onFilters,
  onPlace,
  onClose,
}: TradePickerProps) {
  const dialog = useRef<HTMLDialogElement>(null)
  const grid = useRef<HTMLUListElement>(null)
  const body = useRef<HTMLDivElement>(null)
  const more = useRef<HTMLDivElement>(null)
  const focusAfter = useRef<number | null>(null)
  const placeButton = useRef<HTMLButtonElement>(null)
  const [selection, setSelection] = useState<Line[]>(lines)
  const [refused, setRefused] = useState(false)
  const search = useRef<HTMLInputElement>(null)
  const { filter, folded } = filters
  const [activeKey, setActiveKey] = useState<string | null>(() => (lines.length > 0 ? lines[0].key : null))
  const closed = useRef(onClose)
  closed.current = onClose
  const closeHtml = useMemo(() => ({ __html: closeIcon }), [closeIcon])
  const chevronHtml = useMemo(() => ({ __html: chevronIcon }), [chevronIcon])

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

  const visible = useMemo(() => filterCards(side.cards, filter), [side.cards, filter])
  const [paging, setPaging] = useState({ filter, shown: PICKER_PAGE })
  const shown = paging.filter === filter ? paging.shown : PICKER_PAGE
  const growTo = (next: number) => setPaging({ filter, shown: Math.max(shown, next) })
  const rendered = useMemo(() => visible.slice(0, shown), [visible, shown])
  const hasMore = rendered.length < visible.length
  const found = activeKey === null ? -1 : rendered.findIndex((card) => card.key === activeKey)
  const active = Math.max(0, found)

  useEffect(() => onFacesNeeded(rendered.map((card) => card.key)), [rendered, onFacesNeeded])

  useEffect(() => {
    if (found < 0 && rendered.length > 0) setActiveKey(rendered[0].key)
  }, [found, rendered])

  useLayoutEffect(() => {
    if (body.current) body.current.scrollTop = 0
  }, [filter])

  useEffect(() => {
    const root = body.current
    const target = more.current
    if (!hasMore || !root || !target) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) setPaging({ filter, shown: nextPage(shown) })
      },
      { root, rootMargin: "0px 0px 100% 0px" },
    )
    observer.observe(target)
    return () => observer.disconnect()
  }, [hasMore, filter, shown])

  useLayoutEffect(() => {
    const index = focusAfter.current
    if (index === null || index >= rendered.length) return
    focusAfter.current = null
    grid.current?.querySelectorAll<HTMLElement>(":scope > .trade-pick")[index]?.querySelector<HTMLButtonElement>(".trade-pick__toggle")?.focus()
  })

  const chipsOn = activeChips(filter)
  const setFilter = (next: SideFilter) => onFilters(withFilter(filters, next))

  const clearFilters = () => {
    onFilters(clearedFilters(filters))
    search.current?.focus()
  }

  const selected = useRef(selection)
  selected.current = selection

  const pick = useCallback((card: TradeCard) => {
    setActiveKey(card.key)
    const next = toggle(selected.current, card.key, card.max)
    setRefused(next.refused)
    setSelection(next.lines)
  }, [])

  const changeQuantity = useCallback(
    (card: TradeCard, value: number) => setSelection((current) => setQuantity(current, card.key, value, card.max)),
    [],
  )

  const onGridKeyDown = (event: KeyboardEvent<HTMLUListElement>) => {
    const target = event.target as HTMLElement
    if (!target.classList.contains("trade-pick__toggle") || !grid.current) return
    const items = Array.from(grid.current.querySelectorAll<HTMLElement>(":scope > .trade-pick"))
    const columns = columnsOf(items.map((item) => item.offsetTop))
    const next = gridMove(active, event.key, visible.length, columns)
    if (next === null) return
    event.preventDefault()
    setActiveKey(visible[next]?.key ?? null)
    if (next < items.length) {
      items[next].querySelector<HTMLButtonElement>(".trade-pick__toggle")?.focus()
    } else {
      focusAfter.current = next
      growTo(shownFor(next))
    }
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
              value={filter.query}
              autoComplete="off"
              placeholder={strings.searchPlaceholder}
              onChange={(event) => setFilter({ ...filter, query: event.target.value })}
            />
            <button
              type="button"
              className="trade-picker__fold"
              aria-expanded={!folded}
              aria-controls="trade-picker-groups"
              onClick={() => onFilters(toggledFold(filters))}
            >
              <span className="trade-picker__chevron" aria-hidden="true" dangerouslySetInnerHTML={chevronHtml} />
              <span className="filters__title">{strings.filtersTitle}</span>
              {chipsOn > 0 && (
                <span className="filters__count">
                  <span className="visually-hidden">{strings.filtersActive}</span> {chipsOn}
                </span>
              )}
            </button>
            <div
              id="trade-picker-groups"
              className={["trade-picker__groups", folded ? "trade-picker__groups--folded" : null].filter(Boolean).join(" ")}
            >
              <fieldset className="filters__group trade-picker__rarities">
                <legend className="filters__legend">{strings.raritiesLegend}</legend>
                {RARITIES.map((rarity) => (
                  <label key={rarity} className="filter-chip">
                    <input
                      type="checkbox"
                      className="filter-chip__box"
                      checked={filter.rarities.includes(rarity)}
                      onChange={() => setFilter({ ...filter, rarities: toggled(filter.rarities, rarity) })}
                    />
                    <span className="filter-chip__text">{strings.rarities[rarity]}</span>
                  </label>
                ))}
              </fieldset>
              <fieldset className="filters__group trade-picker__compare">
                <legend className="filters__legend">{strings.compareLegend}</legend>
                {labelledChips(side.side, strings.chips).map(({ chip, label }) => (
                  <label key={chip} className="filter-chip">
                    <input
                      type="checkbox"
                      className="filter-chip__box"
                      checked={filter.chips.includes(chip)}
                      onChange={() => setFilter({ ...filter, chips: toggled(filter.chips, chip) })}
                    />
                    <span className="filter-chip__text">{label}</span>
                  </label>
                ))}
              </fieldset>
            </div>
            <div className="trade-picker__filter-foot">
              <p className="trade-picker__results" aria-live="polite">
                {t(strings.results, { count: visible.length })}
              </p>
              {filtering(filter) && (
                <button type="button" className="filters__clear trade-picker__clear" onClick={clearFilters}>
                  {strings.clearFilters}
                </button>
              )}
            </div>
          </div>
        )}
        <div ref={body} className="trade-picker__body">
          {nothingToPlace && (
            <p className="trade-picker__empty">
              <b className="trade-picker__empty-title">{strings.noneTitle}</b> {nothingToPlace}
            </p>
          )}
          {side.cards.length > 0 && !nothingToPlace && visible.length === 0 && <p className="trade-picker__empty">{strings.noMatch}</p>}
          {visible.length > 0 && (
            <ul ref={grid} className="trade-picker__grid" aria-labelledby="trade-picker-title" onKeyDown={onGridKeyDown}>
              {rendered.map((card, index) => (
                <TradePick
                  key={card.key}
                  card={card}
                  face={faces.get(card.key)}
                  quantity={picked.get(card.key)}
                  focusable={index === active}
                  strings={strings}
                  onPick={pick}
                  onQuantity={changeQuantity}
                />
              ))}
            </ul>
          )}
          {hasMore && <div ref={more} className="trade-picker__more" aria-hidden="true" />}
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

type TradePickProps = {
  card: TradeCard
  face: string | undefined
  quantity: number | undefined
  focusable: boolean
  strings: TradeBoardStrings
  onPick: (card: TradeCard) => void
  onQuantity: (card: TradeCard, value: number) => void
}

const TradePick = memo(function TradePick({ card, face, quantity, focusable, strings, onPick, onQuantity }: TradePickProps) {
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
    <li className="trade-pick">
      <div
        className={[
          "trade-pick__card",
          isPicked ? "trade-pick__card--picked" : null,
          unavailable ? "trade-pick__card--unavailable" : null,
        ]
          .filter(Boolean)
          .join(" ")}
      >
        <div
          className={face === undefined ? "trade-pick__face trade-pick__face--pending" : "trade-pick__face"}
          aria-hidden="true"
          dangerouslySetInnerHTML={{ __html: face ?? "" }}
        />
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
          tabIndex={focusable ? 0 : -1}
          aria-pressed={isPicked}
          aria-disabled={unavailable && !isPicked ? true : undefined}
          aria-label={label}
          onClick={() => onPick(card)}
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
            onChange={(value) => onQuantity(card, value)}
          />
        ) : (
          <span className="trade-pick__available">{t(strings.available, { count: Math.max(0, card.max) })}</span>
        )}
      </div>
    </li>
  )
})
