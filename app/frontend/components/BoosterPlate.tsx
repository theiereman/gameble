// The phone's plate band (DESIGN.md, Reveal caption plate; EXPERIENCE.md,
// Booster; story 8.12): a 52px band between the large card and the tray.
// While the top card is face down it holds the hint line; once the card is
// revealed, the caption plate covers the hint: the rarity icon, the rarity
// name (hazard ticks on Épique and Légendaire, the Légendaire's "!"), the
// title and year, and "Ranger", which stores the card as the swipe does.
// The plate is where the Épique and Légendaire banners play on the phone:
// it pops in (PLATE_POP_MS, longer for a Légendaire; no pop under reduced
// motion) and never covers the card.
import { useLayoutEffect, useMemo, useRef } from "react"
import type { Rarity } from "../lib/card_types"
import { PLATE_POP_LEGENDARY_MS, PLATE_POP_MS } from "../lib/booster"
import { motionReduced } from "../lib/motion"

export type PlateCard = {
  /** One per card: a new key pops a new plate. */
  key: string
  tier: Rarity
  /** The tier's pixel icon, as HTML. */
  icon: string
  /** "Commune", or "Légendaire !". */
  tierText: string
  /** "Golden Crown · 1998". */
  line: string
}

export type BoosterPlateProps = {
  plate: PlateCard | null
  hint: string | null
  storeLabel: string
  /** Something runs (an opening, Tout révéler, a lock or a store): "Ranger" says so and ignores activation. During the 400ms guard a press is ignored by the island. */
  storeBusy: boolean
  onStore: () => void
}

export default function BoosterPlate({ plate, hint, storeLabel, storeBusy, onStore }: BoosterPlateProps) {
  return (
    <div className="booster-plate-band">
      {hint && (
        <p className="booster__hint booster-plate-band__hint" aria-hidden={plate ? "true" : undefined}>
          {hint}
        </p>
      )}
      {plate && <Plate key={plate.key} plate={plate} storeLabel={storeLabel} storeBusy={storeBusy} onStore={onStore} />}
    </div>
  )
}

function Plate({ plate, storeLabel, storeBusy, onStore }: { plate: PlateCard; storeLabel: string; storeBusy: boolean; onStore: () => void }) {
  const element = useRef<HTMLDivElement>(null)
  const iconHtml = useMemo(() => ({ __html: plate.icon }), [plate.icon])
  const banner = plate.tier === "epic" || plate.tier === "legendary"

  // The pop, once per plate (transform and opacity only).
  useLayoutEffect(() => {
    const node = element.current
    if (!node || motionReduced() || typeof node.animate !== "function") return
    const animation = node.animate(
      [
        { transform: "scale(1.2, 0.2)", opacity: 0 },
        { transform: "scale(0.96, 1.12)", opacity: 1, offset: 0.45 },
        { transform: "scale(1.02, 0.98)", opacity: 1, offset: 0.75 },
        { transform: "scale(1, 1)", opacity: 1 },
      ],
      { duration: plate.tier === "legendary" ? PLATE_POP_LEGENDARY_MS : PLATE_POP_MS, easing: "cubic-bezier(.2,1.35,.35,1)" },
    )
    return () => animation.cancel()
  }, [plate.tier])

  return (
    <div className="booster-plate" ref={element} data-tier={plate.tier}>
      <div className="booster-plate__text">
        <p className="booster-plate__tier" data-banner={banner ? "" : undefined}>
          {banner && <span className="booster-plate__tick" aria-hidden="true" />}
          <span className="booster-plate__icon" aria-hidden="true" dangerouslySetInnerHTML={iconHtml} />
          <span className="booster-plate__tier-name">{plate.tierText}</span>
          {banner && <span className="booster-plate__tick" aria-hidden="true" />}
        </p>
        <p className="booster-plate__line">{plate.line}</p>
      </div>
      <button
        type="button"
        className="button button--secondary booster-plate__store"
        aria-disabled={storeBusy ? "true" : undefined}
        onClick={() => {
          if (!storeBusy) onStore()
        }}
      >
        {storeLabel}
      </button>
    </div>
  )
}
