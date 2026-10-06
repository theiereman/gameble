module Catalog
  # The cards of the collection's grid (CAP-6; DESIGN.md, Collection), for
  # one scope of a season: the whole season, or one of its sets found by
  # kind and key (AD-15: never by id). Answers:
  #
  # - `set`: the set as a SetSlots::SetRef (kind, key, params), nil for the
  #   whole season;
  # - `genres`: the genre keys of the scope's cards (their tomes' `genre`
  #   param, CardViews::GENRE), sorted; one query;
  # - `genre`: the genre asked when it is one of `genres`, else nil (an
  #   unknown genre is ignored);
  # - `card_seasons`: the scope's card-seasons with a rarity, filtered on
  #   `genre`, as a lazy, ordered Catalog::CardSeason relation the web layer
  #   pages in SQL: the season by number then id, a set by membership
  #   position then id.
  #
  # nil when a set is asked that the season does not hold under that kind
  # and key. Its lookup is one more query.
  #
  #   Catalog::CollectionGrid.call(season:, genre: "rpg")
  #   Catalog::CollectionGrid.call(season:, kind: "tome", key: "action-1")
  #   # => Grid(set: SetRef | nil, genres: [ "action", "rpg" ], genre: "rpg" | nil, card_seasons: relation) | nil
  module CollectionGrid
    Grid = Data.define(:set, :genres, :genre, :card_seasons)

    # The genres of a set's cards: their tomes, through a second membership.
    SET_GENRES = <<~SQL.squish.freeze
      SELECT DISTINCT tome.params->>'genre' FROM catalog_set_memberships member
        JOIN catalog_set_memberships tome_member ON tome_member.card_season_id = member.card_season_id
        JOIN catalog_sets tome ON tome.id = tome_member.set_id AND tome.kind = 'tome'
       WHERE member.set_id = :set_id
    SQL

    def self.call(season:, kind: nil, key: nil, genre: nil)
      cards = CardSeason.where(season_id: season.id).where.not(rarity: nil)
      set = nil
      if kind
        set_id, set_kind, set_key, params = Set.where(season_id: season.id, kind: kind.to_s, key: key.to_s)
          .pick(:id, :kind, :key, :params)
        return if set_id.nil?

        set = SetSlots::SetRef.new(kind: set_kind, key: set_key, params:)
        genres = Set.connection.select_values(Set.sanitize_sql_array([ SET_GENRES, { set_id: } ]), "Catalog::CollectionGrid")
        cards = cards.joins(:set_memberships).where(catalog_set_memberships: { set_id: })
          .order(Arel.sql("catalog_set_memberships.position, catalog_set_memberships.id"))
      else
        genres = Set.where(season_id: season.id, kind: "tome").distinct.pluck(Arel.sql("catalog_sets.params->>'genre'"))
        cards = cards.order(:number, :id)
      end

      genres = genres.compact.sort
      genre = nil unless genres.include?(genre)
      cards = cards.where("#{CardViews::GENRE} = ?", genre) if genre
      Grid.new(set:, genres:, genre:, card_seasons: cards)
    end
  end
end
