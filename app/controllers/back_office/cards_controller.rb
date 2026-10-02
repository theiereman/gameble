module BackOffice
  # The card preview (epic 3, story 3.5), administrators only: every tier's
  # face and back at both sizes, and one back under each dust level, drawn by
  # CardComponent and, beside it, by the React Card (the CardPreview island),
  # each pair under the same data-pair. The cards are built here, without the
  # database; their art is a sample bundled with the application, except the
  # emerald's, a same-origin URL that answers 404.
  class CardsController < ApplicationController
    PUBLISHERS = { steel: nil, emerald: "Hillside Works", sapphire: "Deepwater", amethyst: "Brotherhood Press", gold: "Crown & Sons" }.freeze
    YEARS = { steel: 2024, emerald: 2019, sapphire: 2014, amethyst: 2007, gold: 1998 }.freeze
    SEASONS = { steel: 1, emerald: 3, sapphire: 12, amethyst: 2, gold: 1 }.freeze
    MISSING_ART = :emerald
    DUST_TIER = :sapphire

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
          image_url: rarity == MISSING_ART ? missing_art_url : helpers.vite_asset_path("images/card_preview/sample.png")
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
