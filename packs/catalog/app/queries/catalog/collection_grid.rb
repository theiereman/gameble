module Catalog
  # The cards of the collection's grid: the whole season, newest gained
  # first by the web layer. Answers:
  #
  # - `genres`: the main themes of the season's cards (CardViews::GENRE),
  #   sorted; one query;
  # - `chosen_genres`: the genres asked that are among `genres` (an unknown
  #   one is ignored);
  # - `chosen_rarities`: the rarity names asked that exist (others ignored);
  # - `chosen_sets`: the sets asked as "kind:key" that the season holds, as
  #   SetRefs, in the order asked;
  # - `card_seasons`: the season's card-seasons with a rarity, filtered on the
  #   chosen genres, rarities and sets (OR within a group, AND across) and on
  #   `query`, a text found in the card's title in `locale` or its publisher
  #   (case-insensitive), as a lazy Catalog::CardSeason relation ordered by
  #   number then id, which the web layer pages in SQL.
  #
  #   Catalog::CollectionGrid.call(season:, genres: [ "rpg" ], rarities: [ "rare" ], sets: [ "theme:roguelike" ], query: "port", locale: "en")
  #   # => Grid(genres: [ "puzzle", "rpg" ], chosen_genres: [ "rpg" ], chosen_rarities: [ "rare" ],
  #   #         chosen_sets: [ SetRef ], card_seasons: relation)
  module CollectionGrid
    Grid = Data.define(:genres, :chosen_genres, :chosen_rarities, :chosen_sets, :card_seasons)

    # The longest text searched.
    MAX_QUERY = 100

    def self.call(season:, genres: [], rarities: [], sets: [], query: nil, locale: I18n.locale)
      genres_asked = genres
      cards = CardSeason.where(season_id: season.id).where.not(rarity: nil)

      genres = cards.where.not(main_theme: nil).distinct.pluck(:main_theme).sort
      cards = cards.order(:number, :id)
      chosen_genres = genres & Array(genres_asked).map(&:to_s)
      cards = cards.where(main_theme: chosen_genres) if chosen_genres.any?

      chosen_rarities = Rarity::TIERS.values.map(&:to_s) & Array(rarities).map(&:to_s)
      cards = cards.where(rarity: chosen_rarities) if chosen_rarities.any?

      chosen_sets = chosen_sets_of(season, sets)
      if chosen_sets.any?
        ids = Set.where(season_id: season.id).where(kind: chosen_sets.map(&:kind), key: chosen_sets.map(&:key)).pluck(:id, :kind, :key)
          .filter_map { |id, set_kind, set_key| id if chosen_sets.any? { it.kind == set_kind && it.key == set_key } }
        cards = cards.where(id: SetMembership.where(set_id: ids).select(:card_season_id))
      end

      text = query.to_s.strip.first(MAX_QUERY)
      cards = cards.where(text_match(text, locale)) if text.present?
      Grid.new(genres:, chosen_genres:, chosen_rarities:, chosen_sets:, card_seasons: cards)
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
