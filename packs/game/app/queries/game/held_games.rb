module Game
  # The games a player holds, whatever the season of their copies: per card,
  # the best rarity among the card-seasons held with copies left.
  #
  #   Game::HeldGames.call(player_id) # => { card_id => rarity, … }
  #   Game::HeldGames.call(player_id, card_ids: [ … ]) # those cards only
  module HeldGames
    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.card_id, MAX(catalog_card_seasons.rarity) AS rarity
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
       GROUP BY catalog_card_seasons.card_id
    SQL

    def self.call(player_id, card_ids: nil)
      return {} if card_ids&.empty?

      sql = card_ids ? "SELECT * FROM (#{SQL}) AS held WHERE held.card_id IN (:card_ids)" : SQL
      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ sql, { player_id:, card_ids: } ]), "Game::HeldGames")
      rows.to_h { |card_id, rarity| [ card_id.to_i, rarity&.to_i ] }
    end
  end
end
