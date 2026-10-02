// The React side of the back-office card preview (BackOffice::CardsController):
// each card the page draws on the server, drawn again by the React Card, under
// the same data-pair, so the two can be compared. Back-office only.
import Card, { type CardSide, type CardStrings, type CardView } from "./Card"
import type { CardSize } from "../lib/card_art"

export type CardPreviewPair = {
  pair: string
  label: string
  card: CardView
  size: CardSize
  side: CardSide
}

export type CardPreviewProps = {
  pairs: CardPreviewPair[]
  strings: CardStrings
}

export default function CardPreview({ pairs, strings }: CardPreviewProps) {
  return (
    <div className="card-preview__cards">
      {pairs.map(({ pair, label, card, size, side }) => (
        <figure className="card-preview__item" key={pair} data-pair={pair} data-renderer="react">
          <figcaption className="card-preview__label">{label}</figcaption>
          <Card card={card} size={size} side={side} strings={strings} />
        </figure>
      ))}
    </div>
  )
}
