// The phone's tray: "Carte n / N" and one 44 × 60 slot per card of the
// pack, in position order. An empty slot is a hatched box (the next one
// outlined); a stored card fills its slot with its cover through the pixel
// filter, at 22 × 30 art pixels with the face's palette (hidden when it
// does not load), and its rarity icon, and the slot becomes a button that
// opens the card zoom. While anything runs the filled slots say so
// (`aria-disabled`) and ignore activation.
import { memo, useEffect, useMemo, useRef } from "react"
import { drawCardArt } from "../lib/card_art"
import type { Rarity } from "../lib/card_types"

export type TraySlot = {
  tier: Rarity
  coverUrl: string
  /** The filled slot's accessible name: "Hades — …, Épique. Agrandir." */
  name: string
}

type ArtSize = { width: number; height: number }

// The 44 × 60 slot, one art pixel being 2 CSS pixels.
const THUMBNAIL: ArtSize = { width: 22, height: 30 }

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
  /** The size a card's palette is computed at, so a thumbnail shows its face's colours. */
  artPalette: ArtSize
  busy: boolean
  slotRef: (index: number, element: HTMLElement | null) => void
  onOpen: (index: number) => void
}

function BoosterTray({ label, countLabel, count, slots, stored, rarityIcons, artPalette, busy, slotRef, onOpen }: BoosterTrayProps) {
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
              <FilledSlot
                index={index}
                slot={slot}
                icon={rarityIcons[slot.tier]}
                palette={artPalette}
                busy={busy}
                slotRef={slotRef}
                onOpen={onOpen}
              />
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
  palette,
  busy,
  slotRef,
  onOpen,
}: {
  index: number
  slot: TraySlot
  icon: string
  palette: ArtSize
  busy: boolean
  slotRef: (index: number, element: HTMLElement | null) => void
  onOpen: (index: number) => void
}) {
  const iconHtml = useMemo(() => ({ __html: icon }), [icon])
  const slotElement = useRef<HTMLButtonElement | null>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  useEffect(() => {
    if (!slotElement.current || !canvas.current) return
    const abort = new AbortController()
    void drawCardArt(slotElement.current, canvas.current, slot.coverUrl, {
      ...THUMBNAIL,
      paletteWidth: palette.width,
      paletteHeight: palette.height,
      signal: abort.signal,
    })
    return () => abort.abort()
  }, [slot.coverUrl, palette.width, palette.height])
  return (
    <button
      type="button"
      ref={(element) => {
        slotElement.current = element
        slotRef(index, element)
      }}
      className="booster-tray__slot booster-tray__slot--filled"
      data-tier={slot.tier}
      aria-label={slot.name}
      aria-disabled={busy ? "true" : undefined}
      onClick={() => {
        if (!busy) onOpen(index)
      }}
    >
      <canvas ref={canvas} className="booster-tray__cover" aria-hidden="true" />
      <span className="booster-tray__icon" aria-hidden="true" dangerouslySetInnerHTML={iconHtml} />
    </button>
  )
}

export default memo(BoosterTray)
