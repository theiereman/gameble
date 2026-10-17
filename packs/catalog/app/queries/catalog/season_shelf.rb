module Catalog
  # A season's sets as the library reads them.
  #
  # `every_kind` is the season's sets of every kind on one shelf: themes,
  # franchises, studios, hall of fame (in HallOfFame's order), then the
  # UFOs, each kind by key otherwise; nil without a season.
  #
  # `kinds` is the kinds the season holds sets of, unordered; none without a
  # season.
  #
  #   Catalog::SeasonShelf.every_kind(season:) # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.kinds(season:)      # => [ "theme", "ufo" ]
  module SeasonShelf
    # A hall of fame set's rank in HallOfFame's order; null for other kinds.
    HALL_OF_FAME_ORDER = Arel.sql(
      "CASE WHEN catalog_sets.kind = 'hall_of_fame' THEN CASE catalog_sets.key " \
      "#{HallOfFame.keys.each_with_index.map { |key, index| "WHEN '#{key}' THEN #{index}" }.join(" ")} END END"
    ).freeze

    # The kinds on a shelf of every kind, then each kind's own order.
    EVERY_KIND_ORDER = Arel.sql(<<~SQL.squish).freeze
      CASE catalog_sets.kind WHEN 'theme' THEN 0 WHEN 'franchise' THEN 1 WHEN 'studio' THEN 2 WHEN 'hall_of_fame' THEN 3
        WHEN 'ufo' THEN 4 ELSE 5 END,
      catalog_sets.kind,
      #{HALL_OF_FAME_ORDER},
      catalog_sets.key
    SQL

    # The season's sets of every kind (lazy); nil without a season.
    def self.every_kind(season:)
      return if season.nil?

      Set.where(season_id: season.id).order(EVERY_KIND_ORDER)
    end

    def self.kinds(season:)
      return [] if season.nil?

      Set.where(season_id: season.id).distinct.pluck(:kind)
    end
  end
end
