module Game
  # A player's spare copies of a game: its free copies, summed over its editions with a rarity, beyond the one its holder keeps.
  module SpareCopies
    BY_GAME = <<~SQL.squish.freeze
      SELECT game_holdings.player_id, catalog_card_seasons.card_id,
             GREATEST(SUM(game_holdings.quantity - game_holdings.reserved) - 1, 0) AS spare
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id IN (:player_ids) AND game_holdings.quantity > 0
         AND catalog_card_seasons.rarity IS NOT NULL
         AND (:all_cards OR catalog_card_seasons.card_id IN (:card_ids))
       GROUP BY game_holdings.player_id, catalog_card_seasons.card_id
    SQL

    # { [player_id, card_id] => spare copies } for the games with at least one.
    def self.by_game(player_ids, card_ids: nil)
      return {} if player_ids.empty? || card_ids&.empty?

      sql = "#{BY_GAME} HAVING SUM(game_holdings.quantity - game_holdings.reserved) > 1"
      Holding.connection.select_rows(sanitize(sql, player_ids, card_ids), "Game::SpareCopies.by_game")
        .to_h { |player_id, card_id, spare| [ [ player_id.to_i, card_id.to_i ], spare.to_i ] }
    end

    def self.total(player)
      return 0 if player.nil?

      sql = "SELECT COALESCE(SUM(games.spare), 0) FROM (#{BY_GAME}) games"
      Holding.connection.select_value(sanitize(sql, [ player.id ], nil), "Game::SpareCopies.total").to_i
    end

    def self.sanitize(sql, player_ids, card_ids)
      Holding.sanitize_sql_array([ sql, { player_ids:, card_ids: card_ids || [ 0 ], all_cards: card_ids.nil? } ])
    end
    private_class_method :sanitize
  end
end
