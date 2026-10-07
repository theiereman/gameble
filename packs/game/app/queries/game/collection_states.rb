module Game
  # The collection grid's state filter (CAP-6; EXPERIENCE.md, Collection
  # opening): a relation of Catalog::CardSeason narrowed to the states asked,
  # OR between them, and optionally put newest gained first. States:
  #
  # - `owned`: at least one copy held;
  # - `missing`: none held;
  # - `new`: held and gained since the player's watermark (AD-26, as in
  #   CollectionSlots);
  # - `duplicates`: two copies or more;
  # - `all`: no restriction.
  #
  # No state asked is `owned`. A visitor (nil) holds nothing: `owned`, `new`
  # and `duplicates` match no card, `missing` and `all` every one. Newest
  # first replaces the relation's order: the held cards before the unheld,
  # by last gain (those never gained last), then the season number and id.
  #
  #   Game::CollectionStates.call(player, relation, states: %w[missing], newest_first: true)
  module CollectionStates
    STATES = %w[owned all missing new duplicates].freeze

    CONDITIONS = {
      "owned" => "game_holdings.id IS NOT NULL",
      "missing" => "game_holdings.id IS NULL",
      "new" => CollectionSlots::NEW,
      "duplicates" => "game_holdings.quantity >= 2"
    }.freeze

    # The states asked that exist, in STATES order.
    def self.sanitize(asked)
      STATES & Array(asked).map(&:to_s)
    end

    def self.call(player, relation, states: [], newest_first: false)
      states = sanitize(states)
      states = %w[owned] if states.empty?
      all = states.include?("all")

      if player.nil?
        return all || states.include?("missing") ? relation : relation.none
      end

      join = Holding.sanitize_sql_array([
        "LEFT JOIN game_holdings ON game_holdings.card_season_id = catalog_card_seasons.id " \
        "AND game_holdings.player_id = ? AND game_holdings.quantity > 0 " \
        "LEFT JOIN game_player_states ON game_player_states.player_id = game_holdings.player_id", player.id
      ])
      relation = relation.joins(join)
      relation = relation.where(CONDITIONS.values_at(*states).map { "(#{it})" }.join(" OR ")) unless all
      relation = relation.reorder(Arel.sql("game_holdings.id IS NULL, game_holdings.last_gained_at DESC NULLS LAST"), :number, :id) if newest_first
      relation
    end
  end
end
