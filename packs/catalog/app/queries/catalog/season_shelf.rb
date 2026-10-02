module Catalog
  # The published season's sets of one kind, in shelf order, for the library
  # (CAP-6): an ungrouped, ordered Catalog::Set relation the web layer pages,
  # or nil when no season is published. Publisher sets by key; tomes by
  # genre key then volume (the English genre key in every locale); best of
  # year, the latest year first. The caller that already holds the published
  # season passes it (nil for none); without it, it is looked up.
  #
  #   Catalog::SeasonShelf.relation(kind: "tome", season:) # => Catalog::Set relation | nil
  module SeasonShelf
    ORDER = {
      "publisher" => Arel.sql("catalog_sets.key"),
      "tome" => Arel.sql("catalog_sets.params->>'genre', (catalog_sets.params->>'volume')::int"),
      "best_of_year" => Arel.sql("catalog_sets.key DESC")
    }.freeze

    # One query for the published season when it is not given; the relation
    # itself is lazy.
    def self.relation(kind:, season: PublishedSeason.call)
      order = ORDER.fetch(kind.to_s)
      return if season.nil?

      Set.where(season_id: season.id, kind: kind.to_s).order(order)
    end
  end
end
