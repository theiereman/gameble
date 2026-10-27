module Catalog
  module SeasonSets
    HALL_OF_FAME_ORDER = Arel.sql(
      "CASE WHEN catalog_sets.kind = 'hall_of_fame' THEN CASE catalog_sets.key " \
      "#{HallOfFame.keys.each_with_index.map { |key, index| "WHEN '#{key}' THEN #{index}" }.join(" ")} END END"
    ).freeze

    def self.every_kind(season:)
      return if season.nil?

      Set.where(season_id: season.id).order(SetKind::ORDER, HALL_OF_FAME_ORDER, :key)
    end

    def self.kinds(season:)
      return [] if season.nil?

      Set.where(season_id: season.id).distinct.pluck(:kind)
    end
  end
end
