module Game
  module CollectionStates
    STATES = %w[owned all missing new duplicates].freeze
    DEFAULT = "all"

    CONDITIONS = {
      "owned" => "held_games.card_id IS NOT NULL",
      "missing" => "held_games.card_id IS NULL",
      "new" => "held_games.fresh",
      "duplicates" => "held_games.copies >= 2"
    }.freeze

    HELD_GAMES = <<~SQL.squish.freeze
      LEFT JOIN (
        SELECT catalog_card_seasons.card_id, SUM(game_holdings.quantity) AS copies,
               MAX(game_holdings.last_gained_at) AS gained_at, BOOL_OR(#{CollectionSlots::NEW}) AS fresh
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          LEFT JOIN game_player_states ON game_player_states.player_id = game_holdings.player_id
         WHERE game_holdings.player_id = ? AND game_holdings.quantity > 0
         GROUP BY catalog_card_seasons.card_id
      ) held_games ON held_games.card_id = catalog_card_seasons.card_id
    SQL

    def self.sanitize(asked)
      states = STATES & Array(asked).map(&:to_s)
      states.size > 1 ? states - [ DEFAULT ] : states
    end

    NEW_SINCE = "held_games.gained_at > ?".freeze

    def self.call(player, relation, states: [], newest_first: false, seen_up_to: nil)
      states = sanitize(states)
      states = [ DEFAULT ] if states.empty?
      all = states.include?("all")

      if player.nil?
        return all || states.include?("missing") ? relation : relation.none
      end

      relation = relation.joins(Holding.sanitize_sql_array([ HELD_GAMES, player.id ]))
      relation = relation.where(conditions(states, seen_up_to).map { "(#{it})" }.join(" OR ")) unless all
      relation = relation.reorder(Arel.sql("held_games.card_id IS NULL, held_games.gained_at DESC NULLS LAST"), :number, :id) if newest_first
      relation
    end

    def self.conditions(states, seen_up_to)
      conditions = CONDITIONS.merge(seen_up_to ? { "new" => Holding.sanitize_sql_array([ NEW_SINCE, seen_up_to ]) } : {})
      conditions.values_at(*states)
    end
    private_class_method :conditions
  end
end
