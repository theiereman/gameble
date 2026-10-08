# The card face, the only one (DESIGN.md: Card face, Card sizes, Rarity
# icon, Rarity effects; AD-16, AD-27, AD-28): every page draws it here, and
# the pack reveal receives it as HTML rendered here. Styled by
# app/frontend/styles/card.css.
#
#   render CardComponent.new(card: view, size: :l)
#   render CardComponent.new(card: view, size: :m, booster: true)
#
# `card` is a Catalog::CardView. Four sizes: s, m, l, xl. The art is drawn
# in the browser by the card-art Stimulus controller (pixelcrush), the
# tilt, glare and holo/foil run by the tilt controller. `booster: true`
# gives a face the booster opening's effects (Rarity effects) and a stronger
# tilt.
class CardComponent < ViewComponent::Base
  SIZES = %i[s m l xl].freeze

  # The art box, in art pixels (one art pixel is 2 CSS pixels): half the
  # art box of each size in DESIGN.md.
  ART = {
    s: { width: 50, height: 51 },
    m: { width: 72, height: 74 },
    l: { width: 94, height: 97 },
    xl: { width: 109, height: 112 }
  }.freeze

  # Each game's palette is computed at the largest art, so a card shows the
  # same colours at every size.
  PALETTE = ART.fetch(:xl)

  # The tilt's strength, in degrees.
  TILT_MAX = 10
  TILT_MAX_BOOSTER = 16

  # Sizes showing the publisher, and the number with its season.
  PUBLISHER_SIZES = %i[m l xl].freeze
  LARGE_SIZES = %i[l xl].freeze

  HOLO = { default: %w[legendary], booster: %w[legendary] }.freeze
  FOIL = { default: [], booster: %w[legendary] }.freeze

  def initialize(card:, size: :m, booster: false)
    raise ArgumentError, "unknown card size: #{size.inspect}" unless SIZES.include?(size)

    @card = card
    @size = size
    @booster = booster
  end

  private
    attr_reader :card, :size, :booster

    def classes
      [ "card", "card--#{size}", "card--rarity-#{card.rarity}", ("card--booster" if booster) ].compact.join(" ")
    end

    def tilt_max = booster ? TILT_MAX_BOOSTER : TILT_MAX

    def art = ART.fetch(size)

    def context = booster ? :booster : :default

    def holo? = HOLO.fetch(context).include?(card.rarity)
    def foil? = FOIL.fetch(context).include?(card.rarity)

    def publisher? = PUBLISHER_SIZES.include?(size) && card.publisher.present?

    def large? = LARGE_SIZES.include?(size)

    def genre = card.genre && SetLabel.genre(card.genre)

    def rarity_name = t("catalog.rarity.#{card.rarity}")

    def rarity_icon
      tier = Catalog::Rarity::TIERS.invert.fetch(card.rarity.to_sym)
      helpers.pixel_icon(large? ? "rarity-#{tier}" : "rarity-compact-#{tier}", class: "card__rarity-icon")
    end

    def number_label = card.number_label(with_season: large?)
end
