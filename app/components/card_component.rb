class CardComponent < ViewComponent::Base
  FIXED_SIZES = %i[s m l xl].freeze
  SIZES = [ *FIXED_SIZES, :grid ].freeze

  ART = {
    s: { width: 50, height: 51 },
    m: { width: 72, height: 74 },
    l: { width: 94, height: 97 },
    xl: { width: 109, height: 112 },
    grid: { width: 72, height: 74 }
  }.freeze

  PALETTE = ART.fetch(:xl)

  TILT_MAX = 10
  TILT_MAX_BOOSTER = 16

  PUBLISHER_SIZES = %i[m l xl grid].freeze
  LARGE_SIZES = %i[l xl].freeze

  IRIDESCENT = %w[legendary].freeze

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

    def glitter_seed = card.season_number.to_i * GLITTER_SEED_SEASON_STRIDE + card.number

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
