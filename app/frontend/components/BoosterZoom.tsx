// The phone's card zoom (DESIGN.md, Card zoom; EXPERIENCE.md, Booster,
// Modal, Focus after each step): a native <dialog> opened with
// showModal(), showing a stored card at card-xl (the answer's xl face drawn
// a second time) between ◀ and ▶, its title, its rarity and year, "Voir la
// fiche" (primary: the card's detail, walking the booster), "Reposter", "Fermer" and
// the tip "Maintenez la carte pour l'incliner"; rays turn behind an Épique
// or a Légendaire. ◀ ▶, or a horizontal swipe on the card, show the
// previous or next stored card in booster order without closing; at an end
// the button is disabled. Esc (the browser's cancel), "Fermer" or a click
// on the scrim closes it; the island then gives the focus back to the tray
// slot shown (lib/dialog.ts's opener pattern, kept by the island since the
// dialog lives in React).
import { useEffect, useMemo, useRef, useState, type MouseEvent, type PointerEvent } from "react"
import type { Rarity } from "../lib/card_types"
import { swipeStep } from "../lib/swipe"

/** ◀ or ▶: its accessible name, its pixel icon (HTML), whether there is a card that way. */
export type ZoomStep = { label: string; icon: string; enabled: boolean }

export type BoosterZoomProps = {
  tier: Rarity
  title: string
  /** The xl face, rendered on the server. */
  face: string
  /** The rarity icon, as HTML. */
  icon: string
  /** "Épique · 2020". */
  line: string
  href: string
  seeCard: string
  close: string
  tip: string
  previous: ZoomStep
  next: ZoomStep
  /** The previous (-1) or next (1) stored card. */
  onStep: (step: -1 | 1) => void
  /** "Voir la fiche" pressed. */
  onSee: (event: MouseEvent<HTMLAnchorElement>) => void
  repost?: { label: string; name: string; onRepost: () => Promise<string> } | null
  onClose: () => void
}

type Gesture = { id: number; x: number; y: number; tilted: boolean }

export default function BoosterZoom({
  tier,
  title,
  face,
  icon,
  line,
  href,
  seeCard,
  close,
  tip,
  previous,
  next,
  onStep,
  onSee,
  repost = null,
  onClose,
}: BoosterZoomProps) {
  const dialog = useRef<HTMLDialogElement>(null)
  const see = useRef<HTMLAnchorElement>(null)
  const gesture = useRef<Gesture | null>(null)
  const faceHtml = useMemo(() => ({ __html: face }), [face])
  const iconHtml = useMemo(() => ({ __html: icon }), [icon])
  const closed = useRef(onClose)
  closed.current = onClose
  const [repostStatus, setRepostStatus] = useState("")

  useEffect(() => {
    const element = dialog.current
    if (!element) return
    const onClosed = () => closed.current()
    element.addEventListener("close", onClosed)
    if (!element.open && typeof element.showModal === "function") element.showModal()
    see.current?.focus()
    return () => {
      element.removeEventListener("close", onClosed)
      if (element.open) element.close()
    }
  }, [])

  // A step that reached an end disabled the button it was pressed on: the
  // focus goes to "Voir la fiche" rather than leaving the dialog.
  useEffect(() => {
    const element = dialog.current
    const focused = document.activeElement
    if (!element?.open) return
    if (!element.contains(focused) || (focused instanceof HTMLButtonElement && focused.disabled)) see.current?.focus()
  }, [previous.enabled, next.enabled])

  const shut = () => {
    if (dialog.current?.open) dialog.current.close()
  }

  // A horizontal swipe on the card steps (touch only); a finger held still
  // tilts the card (lib/tilt.ts) and never swipes.
  const press = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType !== "touch" || !event.isPrimary) return
    gesture.current = { id: event.pointerId, x: event.clientX, y: event.clientY, tilted: false }
  }
  const drag = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current
    if (current && current.id === event.pointerId && event.currentTarget.querySelector("[data-tilting]")) current.tilted = true
  }
  const release = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current
    gesture.current = null
    if (!current || current.id !== event.pointerId || current.tilted) return
    const step = swipeStep(event.clientX - current.x, event.clientY - current.y)
    if (step !== 0 && (step > 0 ? next : previous).enabled) onStep(step)
  }

  const stepButton = (side: ZoomStep, step: -1 | 1, name: string) => (
    <button
      type="button"
      className={`booster-zoom__nav booster-zoom__nav--${name}`}
      aria-label={side.label}
      disabled={!side.enabled}
      onClick={() => onStep(step)}
      dangerouslySetInnerHTML={{ __html: side.icon }}
    />
  )

  return (
    <dialog
      ref={dialog}
      className="booster-zoom"
      data-tier={tier}
      aria-labelledby="booster-zoom-title"
      onClick={(event) => {
        // The panel sits in the middle of the dialog: a click on the dialog itself is on the scrim.
        if (event.target === event.currentTarget) shut()
      }}
    >
      <div className="booster-zoom__panel">
        <div
          className="booster-zoom__stage"
          onPointerDown={press}
          onPointerMove={drag}
          onPointerUp={release}
          onPointerCancel={() => {
            gesture.current = null
          }}
        >
          {stepButton(previous, -1, "previous")}
          <div className="booster-zoom__card">
            {(tier === "epic" || tier === "legendary") && (
              <span className={`card-rays card-rays--${tier} card-rays--large booster-zoom__rays`} aria-hidden="true" />
            )}
            <div className="booster-zoom__face" aria-hidden="true" dangerouslySetInnerHTML={faceHtml} />
          </div>
          {stepButton(next, 1, "next")}
        </div>
        <h2 id="booster-zoom-title" className="booster-zoom__title">
          {title}
        </h2>
        <p className="booster-zoom__line">
          <span className="booster-zoom__icon" aria-hidden="true" dangerouslySetInnerHTML={iconHtml} />
          <span>{line}</span>
        </p>
        <div className="booster-zoom__actions">
          <a ref={see} className="button button--primary booster-zoom__see" href={href} onClick={onSee}>
            {seeCard}
          </a>
          {repost && (
            <button
              type="button"
              className="button button--secondary booster-zoom__repost"
              aria-label={repost.name}
              onClick={async () => setRepostStatus(await repost.onRepost())}
            >
              {repost.label}
            </button>
          )}
          <button type="button" className="button button--secondary booster-zoom__close" onClick={shut}>
            {close}
          </button>
        </div>
        <p className="booster-zoom__tip">{tip}</p>
        {repost && (
          <p className="visually-hidden booster-zoom__status" role="status">
            {repostStatus}
          </p>
        )}
      </div>
    </dialog>
  )
}
