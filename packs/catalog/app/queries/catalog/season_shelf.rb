module Catalog
  # The published season's sets of one kind, in shelf order, for the
  # library: an ungrouped, ordered Catalog::Set relation the web layer
  # pages, or nil when no season is published. Themes, franchises, studios
  # and the UFOs by key, hall of fame sets in HallOfFame's order. The caller
  # that already holds the published season passes it (nil for none);
  # without it, it is looked up.
  #
  # `every_kind` is the season's sets of every kind on one shelf, for a
  # public profile's "Started" tab: themes, franchises, studios, hall of
  # fame, then the UFOs, each kind in its own order.
  #
  # `kinds` is the kinds the season holds sets of, unordered; none without a
  # season.
  #
  #   Catalog::SeasonShelf.relation(kind: "theme", season:) # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.every_kind(season:)              # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.kinds(season:)                   # => [ "theme", "ufo" ]
  module SeasonShelf
    BY_KEY = Arel.sql("catalog_sets.key")
    # A hall of fame set's rank in HallOfFame's order; null for other kinds.
    HALL_OF_FAME_ORDER = Arel.sql(
      "CASE WHEN catalog_sets.kind = 'hall_of_fame' THEN CASE catalog_sets.key " \
      "#{HallOfFame.keys.each_with_index.map { |key, index| "WHEN '#{key}' THEN #{index}" }.join(" ")} END END"
    ).freeze
    ORDER = {
      "hall_of_fame" => Arel.sql("#{HALL_OF_FAME_ORDER}, catalog_sets.key")
    }.freeze

    # The kinds on a shelf of every kind, then each kind's ORDER.
    EVERY_KIND_ORDER = Arel.sql(<<~SQL.squish).freeze
      CASE catalog_sets.kind WHEN 'theme' THEN 0 WHEN 'franchise' THEN 1 WHEN 'studio' THEN 2 WHEN 'hall_of_fame' THEN 3
        WHEN 'ufo' THEN 4 ELSE 5 END,
      catalog_sets.kind,
      #{HALL_OF_FAME_ORDER},
      catalog_sets.key
    SQL

    # One query for the published season when it is not given; the relation
    # itself is lazy.
    def self.relation(kind:, season: PublishedSeason.call)
      return if season.nil?

      Set.where(season_id: season.id, kind: kind.to_s).order(ORDER.fetch(kind.to_s, BY_KEY))
    end

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
