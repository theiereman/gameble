// One card of the pack reveal (story 3.6): a button wrapping the card's back
// and face (the 3.5 Card, unchanged inside), only one side exposed. Wiped by
// a mouse passing over it, a finger touching or sliding on it, or keyboard
// focus; flipped by click, tap, Enter or Space. Its state lives in PackReveal.
import { useLayoutEffect, useState, type CSSProperties, type PointerEvent, type Ref } from "react"
import Card, { type CardStrings, type CardView } from "./Card"
import type { CardSize } from "../lib/card_art"
import { TURN_MS, WIPE_MS, burstPixels, flipLength, type CardState, type FlipMode } from "../lib/reveal"

export type RevealItem = { state: CardState; mode: FlipMode; flippedAt?: number }

export const CARD_PIXELS: Record<CardSize, { width: number; height: number }> = {
  small: { width: 160, height: 240 },
  large: { width: 240, height: 360 },
}

/** Gold rays: two from each side of the card. */
const RAYS = 8

export type RevealCardProps = {
  card: CardView
  item: RevealItem
  size: CardSize
  strings: CardStrings
  reducedMotion: boolean
  onWipe: () => void
  onFlip: () => void
  buttonRef?: Ref<HTMLButtonElement>
}

/** Whether a card flipped at `flippedAt` is still playing its reveal. */
function stillPlaying(item: RevealItem, length: number): boolean {
  return item.flippedAt !== undefined && performance.now() < item.flippedAt + length
}

export default function RevealCard({ card, item, size, strings, reducedMotion, onWipe, onFlip, buttonRef }: RevealCardProps) {
  const { state } = item
  const flipped = state === "flipped"
  const length = flipLength(card.rarity, item.mode)
  // A card mounted after its reveal is over (the phone view moving on) shows
  // its face at once; one flipped now plays its turn and flourish.
  const [playing, setPlaying] = useState(() => stillPlaying(item, length))

  useLayoutEffect(() => {
    if (item.flippedAt === undefined) return
    const remaining = item.flippedAt + length - performance.now()
    if (remaining <= 0) {
      setPlaying(false)
      return
    }
    setPlaying(true)
    const timer = setTimeout(() => setPlaying(false), remaining)
    return () => clearTimeout(timer)
  }, [item.flippedAt, length])

  const wipeOnTouch = (event: PointerEvent<HTMLButtonElement>) => {
    if (event.pointerType === "touch") onWipe()
  }

  const style = {
    "--reveal-ms": `${length}ms`,
    "--reveal-turn-ms": `${TURN_MS}ms`,
    "--reveal-wipe-ms": `${WIPE_MS}ms`,
  } as CSSProperties

  const label = flipped ? undefined : state === "wiped" ? strings.faceDownByRarity[card.rarity] : strings.faceDown
  const { width, height } = CARD_PIXELS[size]

  return (
    <button
      type="button"
      ref={buttonRef}
      className={`reveal-card reveal-card--${size}`}
      style={style}
      data-state={state}
      data-flipped-at={item.flippedAt}
      data-playing={playing ? "" : undefined}
      aria-label={label}
      aria-disabled={flipped ? "true" : undefined}
      onClick={onFlip}
      onFocus={onWipe}
      onPointerEnter={(event) => {
        if (event.pointerType === "mouse") onWipe()
      }}
      onPointerDown={wipeOnTouch}
      onPointerMove={wipeOnTouch}
    >
      <span className="reveal-card__side reveal-card__back" aria-hidden={flipped ? "true" : undefined}>
        <Card card={card} size={size} side="back" strings={strings} sealVisible={state !== "dusty"} />
      </span>
      <span className="reveal-card__side reveal-card__face" aria-hidden={flipped ? undefined : "true"}>
        <Card card={card} size={size} side="face" strings={strings} />
      </span>
      {playing && !reducedMotion && (
        <span className="reveal-card__burst" aria-hidden="true">
          {burstPixels(card.rarity, width, height).map(({ x, y, dx, dy }, index) => (
            <span
              className="reveal-card__pixel"
              key={index}
              style={{ left: `${x}px`, top: `${y}px`, "--dx": `${dx}px`, "--dy": `${dy}px` } as CSSProperties}
            />
          ))}
          {card.rarity === "gold" && (
            <span className="reveal-card__rays">
              {Array.from({ length: RAYS }, (_, index) => (
                <span className="reveal-card__ray" key={index} />
              ))}
            </span>
          )}
        </span>
      )}
    </button>
  )
}
