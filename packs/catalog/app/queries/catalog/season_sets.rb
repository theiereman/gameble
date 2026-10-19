module Catalog
  # A season's sets as the library reads them.
  #
  # `every_kind` is the season's sets of every kind: themes, franchises,
  # studios, hall of fame (in HallOfFame's order), then the UFOs, each kind
  # by key otherwise; nil without a season.
  #
  # `kinds` is the kinds the season holds sets of, unordered; none without a
  # season.
  #
  #   Catalog::SeasonSets.every_kind(season:) # => Catalog::Set relation | nil
  #   Catalog::SeasonSets.kinds(season:)      # => [ "theme", "ufo" ]
  module SeasonSets
    # A hall of fame set's rank in HallOfFame's order; null for other kinds.
    HALL_OF_FAME_ORDER = Arel.sql(
      "CASE WHEN catalog_sets.kind = 'hall_of_fame' THEN CASE catalog_sets.key " \
      "#{HallOfFame.keys.each_with_index.map { |key, index| "WHEN '#{key}' THEN #{index}" }.join(" ")} END END"
    ).freeze

    # The season's sets of every kind (lazy); nil without a season.
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
