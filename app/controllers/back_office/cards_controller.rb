module BackOffice
  # The card preview (epic 3, story 3.5), administrators only: every tier's
  # face at each size, then every tier at size m with the booster's effects,
  # all drawn by CardComponent, each specimen under its data-specimen. The
  # cards are built here, without the database; their art is a sample
  # bundled with the application, except the uncommon's, a same-origin URL
  # that answers 404.
  class CardsController < BaseController
    PUBLISHERS = { common: nil, uncommon: "Hillside Works", rare: "Deepwater", epic: "Brotherhood Press", legendary: "Crown & Sons" }.freeze
    YEARS = { common: 2024, uncommon: 2019, rare: 2014, epic: 2007, legendary: 1998 }.freeze
    SEASONS = { common: 1, uncommon: 3, rare: 12, epic: 2, legendary: 1 }.freeze
    # Card numbers in their season; the epic's is not given yet.
    NUMBERS = { common: 4_215, uncommon: 7, rare: 1_000_000, epic: nil, legendary: 1 }.freeze
    # Main themes (Catalog::Themes keys); the common card has none.
    GENRES = { common: nil, uncommon: "platformer", rare: "puzzle", epic: "visual_novel", legendary: "fps" }.freeze
    MISSING_ART = :uncommon

    def index
      authorize [ :back_office, :cards ], :index?

      cards = Catalog::Rarity::TIERS.values.map { |rarity| sample(rarity) }
      @specimens = cards.flat_map { |card| CardComponent::SIZES.map { |size| specimen(card, size) } } +
        cards.map { |card| specimen(card, :m, booster: true) }
    end

    private
      def sample(rarity)
        Catalog::CardView.new(
          id: "sample-#{rarity}", title: t("back_office.cards.index.samples.#{rarity}"), publisher: PUBLISHERS.fetch(rarity),
          year: YEARS.fetch(rarity), season_number: SEASONS.fetch(rarity), rarity: rarity.to_s,
          image_url: rarity == MISSING_ART ? missing_art_url : helpers.vite_asset_path("images/card_preview/sample.png"),
          number: NUMBERS.fetch(rarity), genre: GENRES.fetch(rarity)
        )
      end

      # Same origin, never served.
      def missing_art_url
        "/back-office-card-preview/missing-art.png"
      end

      def specimen(card, size, booster: false)
        rarity, size_name = t("catalog.rarity.#{card.rarity}"), t("back_office.cards.index.sizes.#{size}")
        label = if booster
          t("back_office.cards.index.booster_label", rarity:, size: size_name)
        else
          t("back_office.cards.index.label", rarity:, size: size_name)
        end
        { specimen: [ card.rarity, size, ("booster" if booster) ].compact.join("-"), label:, card:, size:, booster: }
      end
  end
end
