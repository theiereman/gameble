# One card, face or back, at the small or large size (epic 3, R6, R7;
# DESIGN.md, Card face, Card back, Rarity seal, Dust). The React Card
# (app/frontend/components/Card.tsx) renders the same element tree and
# classes; both share app/frontend/styles/card.css and the pixel parts
# generated into app/frontend/images/card/ (script/card_art/generate.mjs).
#
#   render CardComponent.new(card: view, size: :large, side: :face, strings: CardStrings.for([ view ]))
#
# `card` is a Catalog::CardView. The face's art is drawn in the browser by
# the card-art Stimulus controller, through pixel-art-filter.
class CardComponent < ViewComponent::Base
  SIZES = %i[small large].freeze
  SIDES = %i[face back].freeze

  # The art window, in art pixels (one art pixel is 2 CSS pixels).
  ART = { small: { width: 68, height: 108 }, large: { width: 104, height: 164 } }.freeze

  # The legendary face's sparkles.
  SPARKLES = 7

  # A season seal widens from this season on, to hold two digits.
  WIDE_SEASON = 10

  def initialize(card:, strings:, size: :small, side: :face)
    raise ArgumentError, "unknown card size: #{size.inspect}" unless SIZES.include?(size)
    raise ArgumentError, "unknown card side: #{side.inspect}" unless SIDES.include?(side)

    @card = card
    @strings = strings
    @size = size
    @side = side
  end

  private
    attr_reader :card, :strings, :size, :side

    def classes
      "card card--#{size} card--#{side} card--rarity-#{card.rarity} card--dust-#{card.dust}"
    end

    def face? = side == :face
    def large? = size == :large
    def legendary? = card.rarity == "gold"

    def art = ART.fetch(size)

    def sprite(symbol)
      "#{helpers.vite_asset_path('images/card/sprite.svg')}##{symbol}"
    end

    def glyphs(text)
      text.to_s.upcase.chars
    end

    def wide_season? = card.season_number >= WIDE_SEASON

    def season_classes
      wide_season? ? "card__season card__season--wide" : "card__season"
    end

    def season_seal
      wide_season? ? "season-seal-wide" : "season-seal"
    end
end
