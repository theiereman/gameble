module Game
  # The collection grid's state filter (CAP-6; EXPERIENCE.md, Collection
  # opening): a relation of Catalog::CardSeason narrowed to the states asked,
  # OR between them, and optionally put newest gained first. A state reads
  # the game, every edition of the card-season's card counted. States:
  #
  # - `owned`: at least one copy held, in any edition;
  # - `missing`: none held;
  # - `new`: an edition gained since the player's watermark (as in
  #   CollectionSlots), or since `seen_up_to` when given: the watermark a
  #   grid was shown against, which the grid itself may have moved since;
  # - `duplicates`: two copies or more across editions;
  # - `all`: no restriction.
  #
  # No state asked is DEFAULT, every card. A visitor (nil) holds nothing: `owned`, `new`
  # and `duplicates` match no card, `missing` and `all` every one. Newest
  # first replaces the relation's order: the held games before the unheld,
  # by their latest gain (those never gained last), then the number and id.
  #
  #   Game::CollectionStates.call(player, relation, states: %w[missing], newest_first: true)
  #   Game::CollectionStates.call(player, relation, states: %w[new], seen_up_to: Time)
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

    # The states asked that exist, in STATES order; `all` beside another
    # state gives way to it, so a state chosen from the default narrows.
    def self.sanitize(asked)
      states = STATES & Array(asked).map(&:to_s)
      states.size > 1 ? states - [ DEFAULT ] : states
    end

    # Gained since `seen_up_to`, in place of the player's watermark.
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
