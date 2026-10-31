module Catalog
  module LatestPublishedCardSeasons
    def self.call(card_ids)
      ids = card_ids.uniq
      return {} if ids.empty?

      CardSeason.where(card_id: ids).where.not(rarity: nil).joins(:season).where(catalog_seasons: { status: "published" })
        .order(Arel.sql("catalog_card_seasons.card_id, catalog_seasons.number DESC"))
        .pluck(Arel.sql("DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.card_id"), Arel.sql("catalog_card_seasons.id"))
        .to_h
    end
  end
end
