module BackOffice
  # The card preview (epic 3, story 3.5), administrators only: every tier's
  # face and back at both sizes, and one back under each dust level, drawn by
  # CardComponent and, beside it, by the React Card (the CardPreview island),
  # each pair under the same data-pair. The cards are built here, without the
  # database; their art is a sample bundled with the application, except the
  # uncommon's, a same-origin URL that answers 404.
  class CardsController < ApplicationController
    PUBLISHERS = { common: nil, uncommon: "Hillside Works", rare: "Deepwater", epic: "Brotherhood Press", legendary: "Crown & Sons" }.freeze
    YEARS = { common: 2024, uncommon: 2019, rare: 2014, epic: 2007, legendary: 1998 }.freeze
    SEASONS = { common: 1, uncommon: 3, rare: 12, epic: 2, legendary: 1 }.freeze
    # Card numbers in their season; the epic's is not given yet.
    NUMBERS = { common: 4_215, uncommon: 7, rare: 1_000_000, epic: nil, legendary: 1 }.freeze
    MISSING_ART = :uncommon
    DUST_TIER = :rare

    def index
      authorize [ :back_office, :cards ], :index?

      cards = Catalog::Rarity::TIERS.values.map { |rarity| sample(rarity) }
      @strings = CardStrings.for(cards)
      @pairs = cards.flat_map do |card|
        CardComponent::SIDES.flat_map do |side|
          CardComponent::SIZES.map { |size| pair(card, side, size) }
        end
      end
      dusty = cards.find { |card| card.rarity == DUST_TIER.to_s }
      @pairs += Catalog::Dust::LEVELS.keys.map { |level| pair(dusty.with(dust: level), :back, :small, dust: level) }
    end

    private
      def sample(rarity)
        Catalog::CardView.new(
          id: "sample-#{rarity}", title: t("back_office.cards.index.samples.#{rarity}"), publisher: PUBLISHERS.fetch(rarity),
          year: YEARS.fetch(rarity), season_number: SEASONS.fetch(rarity), rarity: rarity.to_s, dust: 0,
          image_url: rarity == MISSING_ART ? missing_art_url : helpers.vite_asset_path("images/card_preview/sample.png"),
          number: NUMBERS.fetch(rarity), genre: nil
        )
      end

      # Same origin, never served.
      def missing_art_url
        "/back-office-card-preview/missing-art.png"
      end

      def pair(card, side, size, dust: nil)
        rarity = t("catalog.rarity.#{card.rarity}")
        side_name, size_name = t("back_office.cards.index.sides.#{side}"), t("back_office.cards.index.sizes.#{size}")
        {
          pair: [ card.rarity, side, size, ("dust-#{dust}" if dust) ].compact.join("-"),
          label: dust ? t("back_office.cards.index.dust_label", rarity:, side: side_name, size: size_name, level: dust) : t("back_office.cards.index.label", rarity:, side: side_name, size: size_name),
          card:, side:, size:
        }
      end
  end
end
