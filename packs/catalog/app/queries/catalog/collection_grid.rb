module Catalog
  # The cards of the collection's grid (CAP-6; DESIGN.md, Collection), for
  # one scope of a season: the whole season, or one of its sets found by
  # kind and key (AD-15: never by id). Answers:
  #
  # - `set`: the set as a SetSlots::SetRef (kind, key, params), nil for the
  #   whole season;
  # - `genres`: the main themes of the scope's cards (CardViews::GENRE),
  #   sorted; one query;
  # - `chosen_genres`: the genres asked that are among `genres` (an unknown
  #   one is ignored);
  # - `chosen_rarities`: the rarity names asked that exist (others ignored);
  # - `chosen_sets`: the sets asked as "kind:key" that the season holds, as
  #   SetRefs, only on the whole season (a set's own page has no set group);
  # - `card_seasons`: the scope's card-seasons with a rarity, filtered on the
  #   chosen genres, rarities and sets (OR within a group, AND across) and on
  #   `query`, a text found in the card's title in `locale` or its publisher
  #   (case-insensitive), as a lazy, ordered Catalog::CardSeason relation the
  #   web layer pages in SQL: the season by number then id, a set by
  #   membership position then id.
  #
  # nil when a set is asked that the season does not hold under that kind
  # and key. Its lookup is one more query.
  #
  #   Catalog::CollectionGrid.call(season:, genres: [ "rpg" ], rarities: [ "rare" ], query: "port", locale: "en")
  #   Catalog::CollectionGrid.call(season:, kind: "theme", key: "roguelike")
  #   # => Grid(set: SetRef | nil, genres: [ "puzzle", "rpg" ], chosen_genres: [ "rpg" ], chosen_rarities: [ "rare" ],
  #   #         chosen_sets: [], card_seasons: relation) | nil
  module CollectionGrid
    Grid = Data.define(:set, :genres, :chosen_genres, :chosen_rarities, :chosen_sets, :card_seasons)

    # The longest text searched.
    MAX_QUERY = 100

    def self.call(season:, kind: nil, key: nil, genres: [], rarities: [], sets: [], query: nil, locale: I18n.locale)
      genres_asked = genres
      cards = CardSeason.where(season_id: season.id).where.not(rarity: nil)
      set = nil
      if kind
        set_id, set_kind, set_key, params = Set.where(season_id: season.id, kind: kind.to_s, key: key.to_s)
          .pick(:id, :kind, :key, :params)
        return if set_id.nil?

        set = SetSlots::SetRef.new(kind: set_kind, key: set_key, params:)
        cards = cards.joins(:set_memberships).where(catalog_set_memberships: { set_id: })
      end

      genres = cards.where.not(main_theme: nil).distinct.pluck(:main_theme).sort
      cards = set ? cards.order(Arel.sql("catalog_set_memberships.position, catalog_set_memberships.id")) : cards.order(:number, :id)
      chosen_genres = genres & Array(genres_asked).map(&:to_s)
      cards = cards.where(main_theme: chosen_genres) if chosen_genres.any?

      chosen_rarities = Rarity::TIERS.values.map(&:to_s) & Array(rarities).map(&:to_s)
      cards = cards.where(rarity: chosen_rarities) if chosen_rarities.any?

      chosen_sets = set ? [] : chosen_sets_of(season, sets)
      if chosen_sets.any?
        ids = Set.where(season_id: season.id).where(kind: chosen_sets.map(&:kind), key: chosen_sets.map(&:key)).pluck(:id, :kind, :key)
          .filter_map { |id, set_kind, set_key| id if chosen_sets.any? { it.kind == set_kind && it.key == set_key } }
        cards = cards.where(id: SetMembership.where(set_id: ids).select(:card_season_id))
      end

      text = query.to_s.strip.first(MAX_QUERY)
      cards = cards.where(text_match(text, locale)) if text.present?
      Grid.new(set:, genres:, chosen_genres:, chosen_rarities:, chosen_sets:, card_seasons: cards)
    end

    # The sets asked as "kind:key" that the season holds, in the order asked.
    def self.chosen_sets_of(season, asked)
      pairs = Array(asked).filter_map { it.to_s.split(":", 2) if it.to_s.include?(":") }.uniq.first(50)
      return [] if pairs.empty?

      held = Set.where(season_id: season.id, kind: pairs.map(&:first), key: pairs.map(&:last)).pluck(:kind, :key, :params)
        .to_h { |kind, key, params| [ [ kind, key ], params ] }
      pairs.filter_map { |kind, key| SetSlots::SetRef.new(kind:, key:, params: held[[ kind, key ]]) if held.key?([ kind, key ]) }
    end
    private_class_method :chosen_sets_of

    # The card-seasons whose card has `text` in its title in `locale` or in
    # its publisher; the wildcards of LIKE are escaped.
    def self.text_match(text, locale)
      pattern = "%#{Set.sanitize_sql_like(text)}%"
      Set.sanitize_sql_array([
        "catalog_card_seasons.card_id IN (SELECT card_id FROM catalog_card_texts WHERE locale = ? AND title ILIKE ?) " \
        "OR catalog_card_seasons.card_id IN (SELECT id FROM catalog_cards WHERE publisher ILIKE ?)",
        locale.to_s, pattern, pattern
      ])
    end
    private_class_method :text_match
  end
end
