// The booster canister (DESIGN.md, Booster canister; EXPERIENCE.md, Booster
// canister): a flat button of plain layers, the exported pixel art for the
// caps and body (AD-27, story 8.8) and page layers for its label, hazard
// band and LEDs, which turn orange once armed. The Booster island animates
// its layers through the handle; at rest the CSS breathes it, sweeps a band
// of light across it and turns its rays, all stopped under reduced motion.
// While busy it says so (`aria-disabled`) and ignores activation, keeping
// the focus.
import { forwardRef, useImperativeHandle, useRef } from "react"

export type CanisterParts = {
  wrap: HTMLElement | null
  button: HTMLButtonElement | null
  move: HTMLElement | null
  body: HTMLElement | null
  capTop: HTMLElement | null
  capBottom: HTMLElement | null
  rays: HTMLElement | null
}

export type BoosterCanisterProps = {
  /** The accessible name: "Ouvrir le booster Saison 1, grand catalogue, 5 cartes". */
  label: string
  /** The label lines on the body: "Saison 1", "Grand catalogue". */
  seasonLine: string | null
  titleLine: string
  busy: boolean
  armed: boolean
  onActivate: () => void
}

const BoosterCanister = forwardRef<CanisterParts, BoosterCanisterProps>(function BoosterCanister(
  { label, seasonLine, titleLine, busy, armed, onActivate },
  handle,
) {
  const wrap = useRef<HTMLDivElement>(null)
  const button = useRef<HTMLButtonElement>(null)
  const move = useRef<HTMLSpanElement>(null)
  const body = useRef<HTMLSpanElement>(null)
  const capTop = useRef<HTMLSpanElement>(null)
  const capBottom = useRef<HTMLSpanElement>(null)
  const rays = useRef<HTMLDivElement>(null)

  useImperativeHandle(handle, () => ({
    get wrap() {
      return wrap.current
    },
    get button() {
      return button.current
    },
    get move() {
      return move.current
    },
    get body() {
      return body.current
    },
    get capTop() {
      return capTop.current
    },
    get capBottom() {
      return capBottom.current
    },
    get rays() {
      return rays.current
    },
  }))

  return (
    <div className="booster-canister__wrap" ref={wrap} data-armed={armed ? "" : undefined} data-busy={busy ? "" : undefined}>
      <div className="booster-canister__rays" ref={rays} aria-hidden="true" />
      <button
        type="button"
        className="booster-canister"
        ref={button}
        aria-label={label}
        aria-disabled={busy ? "true" : undefined}
        onClick={() => {
          if (!busy) onActivate()
        }}
      >
        <span className="booster-canister__idle">
          <span className="booster-canister__move" ref={move}>
            <span className="booster-canister__body" ref={body}>
              {seasonLine && <span className="booster-canister__line booster-canister__line--season">{seasonLine}</span>}
              <span className="booster-canister__line booster-canister__line--title">{titleLine}</span>
              <span className="booster-canister__hazard" />
              <span className="booster-canister__led booster-canister__led--1" />
              <span className="booster-canister__led booster-canister__led--2" />
              <span className="booster-canister__led booster-canister__led--3" />
              <span className="booster-canister__sweep">
                <span className="booster-canister__sweep-band" />
              </span>
            </span>
            <span className="booster-canister__cap booster-canister__cap--top" ref={capTop}>
              <span className="booster-canister__led booster-canister__led--cap" />
            </span>
            <span className="booster-canister__cap booster-canister__cap--bottom" ref={capBottom} />
          </span>
        </span>
      </button>
    </div>
  )
})

export default BoosterCanister
