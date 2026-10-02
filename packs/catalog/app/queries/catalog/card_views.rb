module Catalog
  # The CardViews of card-seasons, in one query: title in a locale, publisher,
  # release year and art of the card, rarity and dust of the card-season,
  # number of its season. A card-season without rarity or dust (a draft) is
  # left out, as is an unknown id.
  #
  #   Catalog::CardViews.call([ 12, 7 ], locale: "fr")
  #   # => { 12 => CardView(title: "Portal", rarity: "amethyst", …), 7 => … }
  module CardViews
    COLUMNS = [
      "catalog_card_seasons.id", "catalog_cards.slug", "catalog_card_texts.title", "catalog_cards.publisher",
      "catalog_cards.release_date", "catalog_seasons.number", "catalog_card_seasons.rarity",
      "catalog_card_seasons.dust_tier", "catalog_cards.image_url"
    ].freeze

    # The enum columns come back as their names: the rarity is kept as is,
    # the dust turned back into its level.
    def self.call(card_season_ids, locale:)
      return {} if card_season_ids.empty?

      CardSeason.where(id: card_season_ids.uniq)
        .where.not(rarity: nil).where.not(dust_tier: nil)
        .joins(:card, :season)
        .joins("JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_card_seasons.card_id")
        .where(catalog_card_texts: { locale: locale.to_s })
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
        .to_h do |id, slug, title, publisher, release_date, season_number, rarity, dust, image_url|
          [ id, CardView.new(id: slug, title:, publisher:, year: release_date.year, season_number:,
            rarity:, dust: CardSeason.dust_tiers.fetch(dust), image_url:) ]
        end
    end
  end
end
