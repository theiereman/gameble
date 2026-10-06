// The phone's tray (DESIGN.md, Tray; EXPERIENCE.md, Booster; story 8.12):
// "Carte n / N" and one 44 × 60 slot per card of the pack, in position
// order. An empty slot is a hatched box (the next one outlined); a stored
// card fills its slot with its cover, pixelated (hidden when it does not
// load), and its rarity icon, and the slot becomes a button that opens the
// card zoom. While anything runs the filled slots say so (`aria-disabled`)
// and ignore activation.
import { memo, useMemo } from "react"
import type { Rarity } from "../lib/card_types"

export type TraySlot = {
  tier: Rarity
  coverUrl: string
  /** The filled slot's accessible name: "Hades — …, Épique. Agrandir." */
  name: string
}

export type BoosterTrayProps = {
  /** The tray's accessible name, "Cartes rangées". */
  label: string
  /** "Carte", over the count. */
  countLabel: string
  /** "3 / 5". */
  count: string
  slots: TraySlot[]
  stored: boolean[]
  rarityIcons: Record<Rarity, string>
  busy: boolean
  slotRef: (index: number, element: HTMLElement | null) => void
  onOpen: (index: number) => void
}

function BoosterTray({ label, countLabel, count, slots, stored, rarityIcons, busy, slotRef, onOpen }: BoosterTrayProps) {
  const next = stored.findIndex((done) => !done)
  return (
    <div className="booster-tray" role="group" aria-label={label}>
      <p className="booster-tray__count">
        <span className="booster-tray__count-label">{countLabel}</span>
        <span className="booster-tray__count-value">{count}</span>
      </p>
      <ol className="booster-tray__slots">
        {slots.map((slot, index) => (
          <li key={index} className="booster-tray__item">
            {stored[index] ? (
              <FilledSlot index={index} slot={slot} icon={rarityIcons[slot.tier]} busy={busy} slotRef={slotRef} onOpen={onOpen} />
            ) : (
              <span
                ref={(element) => slotRef(index, element)}
                className="booster-tray__slot"
                data-next={index === next ? "" : undefined}
                aria-hidden="true"
              />
            )}
          </li>
        ))}
      </ol>
    </div>
  )
}

function FilledSlot({
  index,
  slot,
  icon,
  busy,
  slotRef,
  onOpen,
}: {
  index: number
  slot: TraySlot
  icon: string
  busy: boolean
  slotRef: (index: number, element: HTMLElement | null) => void
  onOpen: (index: number) => void
}) {
  const iconHtml = useMemo(() => ({ __html: icon }), [icon])
  return (
    <button
      type="button"
      ref={(element) => slotRef(index, element)}
      className="booster-tray__slot booster-tray__slot--filled"
      data-tier={slot.tier}
      aria-label={slot.name}
      aria-disabled={busy ? "true" : undefined}
      onClick={() => {
        if (!busy) onOpen(index)
      }}
    >
      <img
        className="booster-tray__cover"
        src={slot.coverUrl}
        alt=""
        decoding="async"
        onError={(event) => {
          // No cover (unreachable or missing): the slot keeps its frame and icon.
          event.currentTarget.hidden = true
        }}
      />
      <span className="booster-tray__icon" aria-hidden="true" dangerouslySetInnerHTML={iconHtml} />
    </button>
  )
}

export default memo(BoosterTray)
