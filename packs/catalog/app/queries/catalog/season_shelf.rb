module Catalog
  # The published season's sets of one kind, in shelf order, for the library
  # (CAP-6): an ungrouped, ordered Catalog::Set relation the web layer pages,
  # or nil when no season is published. Publisher sets by key; tomes by
  # genre key then volume (the English genre key in every locale); best of
  # year, the latest year first. The caller that already holds the published
  # season passes it (nil for none); without it, it is looked up.
  #
  # `every_kind` is the season's sets of every kind on one shelf, for a
  # public profile's "Started" tab (CAP-8): tomes, then publishers, then
  # best of year, each kind in its own order.
  #
  #   Catalog::SeasonShelf.relation(kind: "tome", season:) # => Catalog::Set relation | nil
  #   Catalog::SeasonShelf.every_kind(season:)             # => Catalog::Set relation | nil
  module SeasonShelf
    ORDER = {
      "publisher" => Arel.sql("catalog_sets.key"),
      "tome" => Arel.sql("catalog_sets.params->>'genre', (catalog_sets.params->>'volume')::int"),
      "best_of_year" => Arel.sql("catalog_sets.key DESC")
    }.freeze

    # The kinds on a shelf of every kind, then each kind's ORDER.
    EVERY_KIND_ORDER = Arel.sql(<<~SQL.squish).freeze
      CASE catalog_sets.kind WHEN 'tome' THEN 0 WHEN 'publisher' THEN 1 ELSE 2 END,
      CASE WHEN catalog_sets.kind = 'tome' THEN catalog_sets.params->>'genre' END,
      CASE WHEN catalog_sets.kind = 'tome' THEN (catalog_sets.params->>'volume')::int END,
      CASE WHEN catalog_sets.kind = 'publisher' THEN catalog_sets.key END,
      CASE WHEN catalog_sets.kind = 'best_of_year' THEN catalog_sets.key END DESC
    SQL

    # One query for the published season when it is not given; the relation
    # itself is lazy.
    def self.relation(kind:, season: PublishedSeason.call)
      order = ORDER.fetch(kind.to_s)
      return if season.nil?

      Set.where(season_id: season.id, kind: kind.to_s).order(order)
    end

    # The season's sets of every kind (lazy); nil without a season.
    def self.every_kind(season:)
      return if season.nil?

      Set.where(season_id: season.id).order(EVERY_KIND_ORDER)
    end
  end
end
