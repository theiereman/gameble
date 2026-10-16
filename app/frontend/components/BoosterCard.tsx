// One dealt card of the booster (EXPERIENCE.md: Face-down card, Revealed
// card, Implementation notes, 3D stack; DESIGN.md, Face-down card and
// revealed card). Plain layers, each with one job, animated by the Booster
// island through WAAPI:
//
//   li.booster-card            data-tier, data-dealt, data-revealed(-at);
//                              on the phone data-top, data-depth, inert
//                              under the top, the pile pose's properties
//     __frame                  the card's box
//       __travel               the deal, the sink, the pile pose (transform, opacity)
//         __float              the phone's swipe drag and store flight
//           __hover            the CSS lift under the pointer or the focus
//           __lift             perspective; the reveal's tremble, jump, settle
//             __glow, __rays   behind the card, once revealed
//             __flip           preserve-3d; `is-up` turns it face up
//               __back         the player's card back
//               __front        the face, HTML from the server (CardComponent)
//       __fx                   the burst and rings
//       button.__hit           flat and transparent, on top: focus, activation
//     __label                  "? ? ?", then the tier's icon and name
//     button.__repost          "Reposter", in a row only, hidden until revealed
//
// No grouping property (opacity under 1, filter, overflow, clip-path, mask,
// blend, isolation) sits on __flip or between __lift and the faces: it
// would flatten the turn and show the mirrored back. The hit button never
// moves; once the card is revealed it lets the pointer through to the
// face's own tilt, and the slot catches the click.
//
// On the phone (story 8.12) the cards lie in a pile: each one at its
// depth's pose (lib/booster.ts, pilePose, read by the stylesheet from
// custom properties), only the top one taking input (the others inert) and
// running its loops.
import { memo, useMemo, type CSSProperties, type MouseEvent, type PointerEvent, type Ref } from "react"
import { cardBackClass, pilePose } from "../lib/booster"
import type { Rarity } from "../lib/card_types"

/** The phone's swipe on the revealed top card, handled by the island. */
export type CardGestures = {
  onPointerDown: (index: number, event: PointerEvent<HTMLLIElement>) => void
  onPointerMove: (index: number, event: PointerEvent<HTMLLIElement>) => void
  onPointerUp: (index: number, event: PointerEvent<HTMLLIElement>) => void
  onPointerCancel: (index: number, event: PointerEvent<HTMLLIElement>) => void
}

export type BoosterCardProps = {
  index: number
  tier: Rarity
  /** The face at the layout's size (s, m or xl), rendered on the server. */
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
  repostLabel?: string
  repostName?: string
  onRepost?: ((index: number) => Promise<unknown>) | null
  /** On the phone: how deep the card lies in the pile (0 on top); null in a row. */
  depth?: number | null
  gestures?: CardGestures | null
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
  repostLabel = "",
  repostName = "",
  onRepost = null,
  depth = null,
  gestures = null,
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

  const repostWithoutOpeningCard = (event: MouseEvent) => {
    event.stopPropagation()
    if (revealed) void onRepost?.(index)
  }

  // The pile: the pose of the card's depth, the top one above the rest.
  const pile = depth === null ? null : pilePose(depth)
  const style = pile
    ? ({ "--pile-y": `${pile.y}px`, "--pile-scale": pile.scale, "--pile-rotate": `${pile.rotate}deg`, zIndex: 20 - (depth ?? 0) } as CSSProperties)
    : undefined
  const top = depth === 0

  return (
    <li
      ref={slotRef}
      className="booster-card"
      style={style}
      data-position={index + 1}
      data-tier={tier}
      data-dealt={dealt ? "" : undefined}
      data-revealed={revealed ? "" : undefined}
      data-revealed-at={revealedAt}
      data-legendary={legendary ? "" : undefined}
      data-top={top ? "" : undefined}
      data-depth={depth ?? undefined}
      inert={depth !== null && !top}
      onClick={activate}
      onPointerDown={gestures ? (event) => gestures.onPointerDown(index, event) : undefined}
      onPointerMove={gestures ? (event) => gestures.onPointerMove(index, event) : undefined}
      onPointerUp={gestures ? (event) => gestures.onPointerUp(index, event) : undefined}
      onPointerCancel={gestures ? (event) => gestures.onPointerCancel(index, event) : undefined}
    >
      <div className="booster-card__frame">
        <div className="booster-card__travel">
          <div className="booster-card__float">
            <div className="booster-card__hover">
              <div className="booster-card__lift">
                {tier === "legendary" && <span className="booster-card__glow" aria-hidden="true" />}
                {(tier === "epic" || tier === "legendary") && (
                  <span className={`card-rays card-rays--${tier} booster-card__rays`} aria-hidden="true" />
                )}
                <div className={revealed ? "booster-card__flip is-up" : "booster-card__flip"}>
                  <div className={`booster-card__back ${cardBackClass(cardBack)}`} aria-hidden="true" />
                  <div className="booster-card__front" aria-hidden="true" dangerouslySetInnerHTML={faceHtml} />
                </div>
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
      {onRepost && depth === null && (
        <button
          type="button"
          className="button button--secondary button--small booster-card__repost"
          aria-label={repostName}
          onClick={repostWithoutOpeningCard}
        >
          {repostLabel}
        </button>
      )}
    </li>
  )
}

export default memo(BoosterCard)
