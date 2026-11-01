module Catalog
  module CardViews
    GENRE = "catalog_card_seasons.main_theme".freeze

    COLUMNS = [
      "catalog_card_seasons.id", "catalog_cards.slug", "catalog_card_texts.title", "catalog_cards.publisher",
      "catalog_cards.release_date", "catalog_seasons.number", "catalog_card_seasons.rarity",
      "catalog_cards.image_url", "catalog_card_seasons.number", GENRE, "catalog_card_seasons.card_id"
    ].freeze

    def self.call(card_season_ids, locale:)
      return {} if card_season_ids.empty?

      CardSeason.where(id: card_season_ids.uniq)
        .where.not(rarity: nil)
        .joins(:card, :season)
        .joins("JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_card_seasons.card_id")
        .where(catalog_card_texts: { locale: locale.to_s })
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
        .to_h do |id, slug, title, publisher, release_date, season_number, rarity, image_url, number, genre, card_id|
          [ id, CardView.new(id: slug, title:, publisher:, year: release_date.year, season_number:,
            rarity:, image_url:, number:, genre:, card_id:) ]
        end
    end
  end
end
