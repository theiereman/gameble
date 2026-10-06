// One dealt card of the booster (EXPERIENCE.md: Face-down card, Revealed
// card, Implementation notes, 3D stack; DESIGN.md, Face-down card and
// revealed card). Plain layers, each with one job, animated by the Booster
// island through WAAPI:
//
//   li.booster-card            data-tier, data-dealt, data-revealed(-at)
//     __frame                  the card's box
//       __travel               the deal and the sink (transform, opacity)
//         __hover              the CSS lift under the pointer or the focus
//           __lift             perspective; the reveal's tremble, jump, settle
//             __glow, __rays   behind the card, once revealed
//             __flip           preserve-3d; `is-up` turns it face up
//               __back         the player's card back
//               __front        the face, HTML from the server (CardComponent)
//       __fx                   the burst and rings
//       button.__hit           flat and transparent, on top: focus, activation
//     __label                  "? ? ?", then the tier's icon and name
//
// No grouping property (opacity under 1, filter, overflow, clip-path, mask,
// blend, isolation) sits on __flip or between __lift and the faces: it
// would flatten the turn and show the mirrored back. The hit button never
// moves; once the card is revealed it lets the pointer through to the
// face's own tilt, and the slot catches the click.
import { memo, useMemo, type MouseEvent, type Ref } from "react"
import type { Rarity } from "../lib/card_types"

/** The card backs the island draws; an unknown key shows the standard one (AD-25). */
const CARD_BACKS = ["standard"] as const

export function cardBackClass(key: string): string {
  return `booster-card__back--${(CARD_BACKS as readonly string[]).includes(key) ? key : "standard"}`
}

export type BoosterCardProps = {
  index: number
  tier: Rarity
  /** The face at m, rendered on the server. */
  face: string
  cardBack: string
  dealt: boolean
  revealed: boolean
  revealedAt: number | undefined
  /** This card's legendary sequence is running (the stage dims the others). */
  legendary: boolean
  /** The hit button's accessible name, face down or revealed. */
  name: string
  /** The label under a revealed card: the tier's icon (HTML) and name. */
  tierIcon: string
  tierLabel: string
  slotRef: Ref<HTMLLIElement>
  onActivate: (index: number) => void
}

function BoosterCard({
  index,
  tier,
  face,
  cardBack,
  dealt,
  revealed,
  revealedAt,
  legendary,
  name,
  tierIcon,
  tierLabel,
  slotRef,
  onActivate,
}: BoosterCardProps) {
  // The same objects while the HTML is the same, so React never rewrites
  // the face (nor the work of its controllers: art, tilt).
  const faceHtml = useMemo(() => ({ __html: face }), [face])
  const iconHtml = useMemo(() => ({ __html: tierIcon }), [tierIcon])

  // A click on the revealed face (the hit button lets the pointer through)
  // reaches the slot; a click on the hit button too.
  const activate = (event: MouseEvent) => {
    event.preventDefault()
    onActivate(index)
  }

  return (
    <li
      ref={slotRef}
      className="booster-card"
      data-tier={tier}
      data-dealt={dealt ? "" : undefined}
      data-revealed={revealed ? "" : undefined}
      data-revealed-at={revealedAt}
      data-legendary={legendary ? "" : undefined}
      onClick={activate}
    >
      <div className="booster-card__frame">
        <div className="booster-card__travel">
          <div className="booster-card__hover">
            <div className="booster-card__lift">
              {tier === "legendary" && <span className="booster-card__glow" aria-hidden="true" />}
              {(tier === "epic" || tier === "legendary") && <span className="booster-card__rays" aria-hidden="true" />}
              <div className={revealed ? "booster-card__flip is-up" : "booster-card__flip"}>
                <div className={`booster-card__back ${cardBackClass(cardBack)}`} aria-hidden="true" />
                <div className="booster-card__front" aria-hidden="true" dangerouslySetInnerHTML={faceHtml} />
              </div>
            </div>
          </div>
        </div>
        <div className="booster-card__fx" aria-hidden="true" />
        <button type="button" className="booster-card__hit" aria-label={name} />
      </div>
      <p className="booster-card__label" aria-hidden="true">
        {revealed ? (
          <>
            <span className="booster-card__label-icon-box" dangerouslySetInnerHTML={iconHtml} />
            <span>{tierLabel}</span>
          </>
        ) : (
          "? ? ?"
        )}
      </p>
    </li>
  )
}

export default memo(BoosterCard)
