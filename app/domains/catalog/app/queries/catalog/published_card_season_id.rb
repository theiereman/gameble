module Catalog
  module PublishedCardSeasonId
    def self.call(slug:, season_number:)
      CardSeason.where.not(rarity: nil).joins(:card, :season)
        .where(catalog_cards: { slug: slug.to_s }, catalog_seasons: { status: "published", number: season_number })
        .pick(:id)
    end
  end
end
