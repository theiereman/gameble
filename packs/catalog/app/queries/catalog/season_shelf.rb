module Catalog
  # The published season's sets of one kind, in shelf order, for the
  # library: an ungrouped, ordered Catalog::Set relation the web layer
  # pages, or nil when no season is published. Themes, franchises, studios
  # and the UFOs by key; the retired kinds as before: publisher sets by key,
  # tomes by genre key then volume (the English genre key in every locale),
  # best of year the latest year first; any other kind by key. The caller that already holds
  # the published season passes it (nil for none); without it, it is looked
  # up.
  #
  # `every_kind` is the season's sets of every kind on one shelf, for a
  # public profile's "Started" tab: themes, franchises, studios, then the
  # UFOs, then the retired tomes, publishers and best of year, each kind in
  # its own order.
  #
  # `kinds` is the kinds the season holds sets of, unordered; none without a
  # season.
  #
  #   Catalog::SeasonShelf.relation(kind: "theme", season:) # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.every_kind(season:)              # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.kinds(season:)                   # => [ "theme", "ufo" ]
  module SeasonShelf
    BY_KEY = Arel.sql("catalog_sets.key")
    ORDER = {
      "tome" => Arel.sql("catalog_sets.params->>'genre', (catalog_sets.params->>'volume')::int"),
      "best_of_year" => Arel.sql("catalog_sets.key DESC")
    }.freeze

    # The kinds on a shelf of every kind, then each kind's ORDER.
    EVERY_KIND_ORDER = Arel.sql(<<~SQL.squish).freeze
      CASE catalog_sets.kind WHEN 'theme' THEN 0 WHEN 'franchise' THEN 1 WHEN 'studio' THEN 2 WHEN 'ufo' THEN 3
        WHEN 'tome' THEN 4 WHEN 'publisher' THEN 5 WHEN 'best_of_year' THEN 6 ELSE 7 END,
      catalog_sets.kind,
      CASE WHEN catalog_sets.kind = 'tome' THEN catalog_sets.params->>'genre' END,
      CASE WHEN catalog_sets.kind = 'tome' THEN (catalog_sets.params->>'volume')::int END,
      CASE WHEN catalog_sets.kind = 'best_of_year' THEN catalog_sets.key END DESC,
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
