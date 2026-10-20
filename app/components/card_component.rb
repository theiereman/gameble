# The card face, the only one: every page draws it here, and the pack
# reveal receives it as HTML rendered here. Styled by
# app/frontend/styles/card.css.
#
#   render CardComponent.new(card: view, size: :l)
#   render CardComponent.new(card: view, size: :m, booster: true)
#
# `card` is a Catalog::CardView. Five sizes: s, m, l and xl, fixed, and
# grid, whose dimensions come from its slot in a grid filling its row (the
# medium layout from 140px wide, the small one below). The art is drawn in
# the browser by the card-art Stimulus controller (pixelcrush), the tilt,
# the reflection on the varnish and a Légendaire's glitter run by the tilt
# controller. `booster: true` gives a face the booster opening's
# rarity effects and a stronger tilt. `owned: false` draws a card
# its viewer does not hold: faded and grey, without its rarity effects or
# tilt, a lock bare over its art.
class CardComponent < ViewComponent::Base
  FIXED_SIZES = %i[s m l xl].freeze
  SIZES = [ *FIXED_SIZES, :grid ].freeze

  # The art box, in art pixels (one art pixel is 2 CSS pixels): half the
  # art box of each size in CSS pixels.
  ART = {
    s: { width: 50, height: 51 },
    m: { width: 72, height: 74 },
    l: { width: 94, height: 97 },
    xl: { width: 109, height: 112 },
    grid: { width: 72, height: 74 }
  }.freeze

  # Each game's palette is computed at the largest art, so a card shows the
  # same colours at every size.
  PALETTE = ART.fetch(:xl)

  # The tilt's strength, in degrees.
  TILT_MAX = 10
  TILT_MAX_BOOSTER = 16

  # Sizes showing the publisher, and the number with its season.
  PUBLISHER_SIZES = %i[m l xl grid].freeze
  LARGE_SIZES = %i[l xl].freeze

  # Tiers whose reflection shows pastel hues, under glitter.
  IRIDESCENT = %w[legendary].freeze

  # Room for every card number in a season, so no two cards share a glitter.
  GLITTER_SEED_SEASON_STRIDE = 1_000_000

  def initialize(card:, size: :m, booster: false, owned: true)
    raise ArgumentError, "unknown card size: #{size.inspect}" unless SIZES.include?(size)

    @card = card
    @size = size
    @booster = booster
    @owned = owned
  end

  private
    attr_reader :card, :size, :booster, :owned

    def classes
      [ "card", "card--#{size}", "card--rarity-#{card.rarity}", ("card--booster" if booster), ("card--not-owned" unless owned) ]
        .compact.join(" ")
    end

    def tilt_max = booster ? TILT_MAX_BOOSTER : TILT_MAX

    def art = ART.fetch(size)

    def iridescent? = IRIDESCENT.include?(card.rarity)

    def glitter_seed = card.season_number.to_i * GLITTER_SEED_SEASON_STRIDE + card.number.to_i

    def publisher? = PUBLISHER_SIZES.include?(size) && card.publisher.present?

    def large? = LARGE_SIZES.include?(size)

    def fluid? = FIXED_SIZES.exclude?(size)

    def genre = card.genre && SetLabel.genre(card.genre)

    def rarity_name = t("catalog.rarity.#{card.rarity}")

    def rarity_icon
      tier = Catalog::Rarity::TIERS.invert.fetch(card.rarity.to_sym)
      helpers.pixel_icon(large? ? "rarity-#{tier}" : "rarity-compact-#{tier}", class: "card__rarity-icon")
    end

    def number_label = card.number_label(with_season: large?)
end
