// The phone's card zoom (DESIGN.md, Card zoom; EXPERIENCE.md, Booster,
// Modal, Focus after each step; story 8.12): a native <dialog> opened with
// showModal(), showing a stored card at card-xl (the answer's xl face drawn
// a second time), its title, its rarity and year, "Voir la fiche"
// (primary: the card's page), "Fermer" and the tip "Maintenez la carte pour
// l'incliner"; rays turn behind an Épique or a Légendaire. Esc (the
// browser's cancel), "Fermer" or a click on the scrim closes it; the island
// then gives the focus back to the tray slot (lib/dialog.ts's opener
// pattern, kept by the island since the dialog lives in React).
import { useEffect, useMemo, useRef } from "react"
import type { Rarity } from "../lib/card_types"

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
  onClose: () => void
}

export default function BoosterZoom({ tier, title, face, icon, line, href, seeCard, close, tip, onClose }: BoosterZoomProps) {
  const dialog = useRef<HTMLDialogElement>(null)
  const faceHtml = useMemo(() => ({ __html: face }), [face])
  const iconHtml = useMemo(() => ({ __html: icon }), [icon])
  const closed = useRef(onClose)
  closed.current = onClose

  useEffect(() => {
    const element = dialog.current
    if (!element) return
    const onClosed = () => closed.current()
    element.addEventListener("close", onClosed)
    if (!element.open && typeof element.showModal === "function") element.showModal()
    return () => {
      element.removeEventListener("close", onClosed)
      if (element.open) element.close()
    }
  }, [])

  const shut = () => {
    if (dialog.current?.open) dialog.current.close()
  }

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
        <div className="booster-zoom__card">
          {(tier === "epic" || tier === "legendary") && <span className="booster-zoom__rays" aria-hidden="true" />}
          <div className="booster-zoom__face" aria-hidden="true" dangerouslySetInnerHTML={faceHtml} />
        </div>
        <h2 id="booster-zoom-title" className="booster-zoom__title">
          {title}
        </h2>
        <p className="booster-zoom__line">
          <span className="booster-zoom__icon" aria-hidden="true" dangerouslySetInnerHTML={iconHtml} />
          <span>{line}</span>
        </p>
        <div className="booster-zoom__actions">
          <a className="button button--primary booster-zoom__see" href={href}>
            {seeCard}
          </a>
          <button type="button" className="button button--secondary booster-zoom__close" onClick={shut}>
            {close}
          </button>
        </div>
        <p className="booster-zoom__tip">{tip}</p>
      </div>
    </dialog>
  )
}
