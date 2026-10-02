module Catalog
  # The published season's sets of one kind, in shelf order, for the library
  # (CAP-6): an ungrouped, ordered Catalog::Set relation the web layer pages,
  # or nil when no season is published. Publisher sets by key; tomes by
  # genre key then volume (the English genre key in every locale); best of
  # year, the latest year first.
  #
  #   Catalog::SeasonShelf.relation(kind: "tome") # => Catalog::Set relation | nil
  module SeasonShelf
    ORDER = {
      "publisher" => Arel.sql("catalog_sets.key"),
      "tome" => Arel.sql("catalog_sets.params->>'genre', (catalog_sets.params->>'volume')::int"),
      "best_of_year" => Arel.sql("catalog_sets.key DESC")
    }.freeze

    # One query, for the published season; the relation itself is lazy.
    def self.relation(kind:)
      order = ORDER.fetch(kind.to_s)
      season = PublishedSeason.call
      return if season.nil?

      Set.where(season_id: season.id, kind: kind.to_s).order(order)
    end
  end
end
