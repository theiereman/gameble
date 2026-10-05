// The pack reveal (CAP-5; EXPERIENCE.md, Face-down card, Flip all, Pack
// reveal on phone; story 3.6), the island AD-16 allows. Mounted once, right
// after an opening: the pack's cards lie face down under dust, seals hidden;
// wiping a card shows its seal, flipping it shows the game. The cards are
// already in the collection, so nothing here calls the server and nothing
// resumes: a later visit shows the faces, server-rendered.
//
// Items, announcements and progress go by position, never by card id: a pack
// can hold the same card more than once.
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react"
import type { CardStrings, CardView } from "./Card"
import RevealCard, { type RevealItem } from "./RevealCard"
import { flip, planFlipAll, runFlipAll, wipe, type FlipMode } from "../lib/reveal"

/** Every word of the reveal, resolved on the server (AD-16). */
export type PackRevealStrings = {
  /** The list of cards. */
  cards: string
  flipAll: string
  next: string
  previous: string
  /** "Card n of N", by position. */
  progress: string[]
  /** Said once flip all is over. */
  allFlipped: string
  /** Shown if the reveal fails, with a link to the pack's page. */
  failed: string
  reload: string
  openNextPack: string
  backToHub: string
}

export type PackRevealProps = {
  cards: CardView[]
  cardStrings: CardStrings
  strings: PackRevealStrings
  /** Where to open the next pack; null when none is available. */
  openPackUrl: string | null
  hubUrl: string
}

/** Whether a media query matches, followed as it changes; never for an empty query. */
function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      if (!query) return () => {}
      const list = window.matchMedia(query)
      list.addEventListener("change", onChange)
      return () => list.removeEventListener("change", onChange)
    },
    [query],
  )
  return useSyncExternalStore(subscribe, () => (query ? window.matchMedia(query).matches : false))
}

// The phone layout's one query lives in the stylesheet (styles/reveal.css,
// --reveal-phone-query); the island reads it there, once.
const phoneQuery = () => getComputedStyle(document.documentElement).getPropertyValue("--reveal-phone-query").trim()
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

/** The live region keeps the latest few announcements; older ones are spoken already. */
const ANNOUNCEMENTS_KEPT = 5

function csrf(): { param: string; token: string } | null {
  const param = document.querySelector<HTMLMetaElement>('meta[name="csrf-param"]')?.content
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
  return param && token ? { param, token } : null
}

export default function PackReveal({ cards, cardStrings, strings, openPackUrl, hubUrl }: PackRevealProps) {
  const [phoneText] = useState(phoneQuery)
  const phone = useMediaQuery(phoneText)
  const reducedMotion = useMediaQuery(REDUCED_MOTION)
  const last = cards.length - 1

  const [items, setItems] = useState<RevealItem[]>(() => cards.map(() => ({ state: "dusty", mode: "full" })))
  // The latest items, read by handlers and flip all's timers between renders.
  const itemsRef = useRef(items)
  const [running, setRunning] = useState(false)
  const runningRef = useRef(false)
  const [current, setCurrent] = useState(0)
  const phoneRef = useRef(phone)
  phoneRef.current = phone
  const currentRef = useRef(current)
  currentRef.current = current

  // The live region: announcements are appended, a new node each, so one
  // never replaces another before it is spoken (a tap wipes then flips at
  // once), and the same words said twice (two identical cards) are read twice.
  const [announcements, setAnnouncements] = useState<{ key: number; text: string }[]>([])
  const announce = useCallback(
    (text: string) =>
      setAnnouncements((previous) => [...previous.slice(-(ANNOUNCEMENTS_KEPT - 1)), { key: (previous.at(-1)?.key ?? 0) + 1, text }]),
    [],
  )

  const update = useCallback((index: number, change: (item: RevealItem) => RevealItem) => {
    const next = itemsRef.current.map((item, position) => (position === index ? change(item) : item))
    itemsRef.current = next
    setItems(next)
  }, [])

  const wipeCard = useCallback(
    (index: number) => {
      if (runningRef.current || itemsRef.current[index].state !== "dusty") return
      update(index, (item) => ({ ...item, state: wipe(item.state) }))
      announce(cardStrings.rarityNames[cards[index].rarity])
    },
    [announce, cardStrings, cards, update],
  )

  const flipCard = useCallback(
    (index: number, mode: FlipMode) => {
      if (itemsRef.current[index].state === "flipped") return
      update(index, (item) => ({ state: flip(item.state), mode, flippedAt: performance.now() }))
    },
    [update],
  )

  const onFlip = (index: number) => {
    if (runningRef.current || itemsRef.current[index].state === "flipped") return
    flipCard(index, "full")
    announce(cards[index].title)
  }

  // Phone: "next" and "previous" move focus to the new card, which wipes it.
  const shownCard = useRef<HTMLButtonElement>(null)
  const cardList = useRef<HTMLOListElement>(null)
  const focusShown = useRef(false)
  useEffect(() => {
    if (!focusShown.current) return
    focusShown.current = false
    shownCard.current?.focus()
  }, [current, phone])

  // Phone, flip all: the shown card leaves the page; its focus, if it had
  // it, goes to the new one rather than to the body.
  const showCard = (index: number) => {
    if (index === currentRef.current) return
    if (cardList.current?.contains(document.activeElement)) focusShown.current = true
    setCurrent(index)
  }

  // Flip all: the rest, quickly, a legendary card held its full length; input is
  // ignored while it runs, and its timers go with the island.
  const cancelFlipAll = useRef<(() => void) | null>(null)
  useEffect(() => () => cancelFlipAll.current?.(), [])

  const flipAll = () => {
    if (runningRef.current) return
    const plan = planFlipAll(
      cards.map((card) => card.rarity),
      itemsRef.current.map((item) => item.state),
    )
    if (plan.steps.length === 0) return
    runningRef.current = true
    setRunning(true)
    cancelFlipAll.current = runFlipAll(plan, {
      onStep: ({ index, mode }) => {
        flipCard(index, mode)
        // On a phone the view moves to each legendary card and holds it.
        if (phoneRef.current && cards[index].rarity === "legendary") showCard(index)
      },
      onEnd: () => {
        cancelFlipAll.current = null
        runningRef.current = false
        setRunning(false)
        // Then back to the first card it turned, to step through the rest.
        if (phoneRef.current) showCard(plan.steps[0].index)
        announce(strings.allFlipped)
      },
    })
  }

  // Crossing into the phone layout shows the focused card, keeping its focus,
  // else the first card not yet flipped. Decided while rendering, before the
  // other cards (and the focus) leave the page.
  const root = useRef<HTMLDivElement>(null)
  const [layoutPhone, setLayoutPhone] = useState(phone)
  if (phone !== layoutPhone) {
    setLayoutPhone(phone)
    if (phone) {
      const focused = document.activeElement?.closest<HTMLLIElement>(".pack-reveal__item")
      const unflipped = items.findIndex((item) => item.state !== "flipped")
      if (focused && root.current?.contains(focused)) {
        focusShown.current = true
        setCurrent(focused.value - 1)
      } else {
        setCurrent(unflipped === -1 ? last : unflipped)
      }
    }
  }

  const next = () => {
    focusShown.current = true
    setCurrent((index) => Math.min(index + 1, last))
  }

  const previous = () => {
    focusShown.current = true
    setCurrent((index) => Math.max(index - 1, 0))
  }

  const allFlipped = items.every((item) => item.state === "flipped")
  const size = phone ? "large" : "small"
  const shown = phone ? [current] : cards.map((_, index) => index)
  const token = openPackUrl ? csrf() : null

  return (
    <div className={phone ? "pack-reveal pack-reveal--phone" : "pack-reveal"} ref={root}>
      <div className="pack-reveal__controls">
        <button
          type="button"
          className="button button--secondary"
          aria-disabled={running || allFlipped ? "true" : undefined}
          onClick={flipAll}
        >
          {strings.flipAll}
        </button>
        {phone && (
          <p className="pack-reveal__progress">
            <span aria-hidden="true">
              {current + 1} / {cards.length}
            </span>
            <span className="visually-hidden">{strings.progress[current]}</span>
          </p>
        )}
      </div>

      <ol className="pack-reveal__cards" aria-label={strings.cards} ref={cardList}>
        {shown.map((index) => (
          <li className="pack-reveal__item" key={index} value={index + 1}>
            <RevealCard
              card={cards[index]}
              item={items[index]}
              size={size}
              strings={cardStrings}
              reducedMotion={reducedMotion}
              onWipe={() => wipeCard(index)}
              onFlip={() => onFlip(index)}
              buttonRef={phone ? shownCard : undefined}
            />
          </li>
        ))}
      </ol>

      {phone && !running && (current > 0 || (current < last && items[current].state === "flipped")) && (
        <div className="pack-reveal__nav">
          {current > 0 && (
            <button type="button" className="button button--secondary" onClick={previous}>
              {strings.previous}
            </button>
          )}
          {current < last && items[current].state === "flipped" && (
            <button type="button" className="button button--secondary" onClick={next}>
              {strings.next}
            </button>
          )}
        </div>
      )}

      <div className="visually-hidden" role="status" aria-live="polite">
        {announcements.map(({ key, text }) => (
          <span key={key}>{text}</span>
        ))}
      </div>

      <div className="pack-end">
        {openPackUrl && (
          <form className="button-form" method="post" action={openPackUrl}>
            {token && <input type="hidden" name={token.param} value={token.token} />}
            <button type="submit" className="button button--primary">
              {strings.openNextPack}
            </button>
          </form>
        )}
        <a className="button button--secondary" href={hubUrl}>
          {strings.backToHub}
        </a>
      </div>
    </div>
  )
}
