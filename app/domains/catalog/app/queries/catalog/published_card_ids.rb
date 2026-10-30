module Catalog
  module PublishedCardIds
    def self.call(source_keys:)
      keys = source_keys.map(&:to_s).uniq
      return [] if keys.empty?

      published = CardSeason.where.not(rarity: nil).joins(:season).where(catalog_seasons: { status: "published" })
      Card.where(source_key: keys).where(id: published.select(:card_id)).order(:id).pluck(:id)
    end
  end
end
