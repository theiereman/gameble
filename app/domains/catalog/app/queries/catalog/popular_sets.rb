module Catalog
  module PopularSets
    AVERAGE_REVIEWS = Arel.sql("COALESCE(AVG(COALESCE(catalog_card_seasons.review_count, 0)), 0) DESC, catalog_sets.id").freeze

    def self.call(season:, limit:, exclude: [])
      return [] if limit <= 0

      Set.where(season_id: season.id).where.not(id: exclude)
        .left_joins(memberships: :card_season)
        .group(:id)
        .order(AVERAGE_REVIEWS)
        .limit(limit)
        .pluck(:id)
    end
  end
end
