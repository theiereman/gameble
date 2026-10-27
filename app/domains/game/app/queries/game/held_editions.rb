module Game
  module HeldEditions
    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.rarity, catalog_seasons.number, game_holdings.quantity
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
         AND catalog_card_seasons.card_id = :card_id AND catalog_card_seasons.rarity IS NOT NULL
       ORDER BY catalog_card_seasons.rarity DESC, catalog_seasons.number
    SQL

    def self.call(player, card_id:)
      return [] if player.nil?

      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ SQL, { player_id: player.id, card_id: } ]), "Game::HeldEditions")
      rows.map { |rarity, season_number, quantity| [ Catalog::Rarity::TIERS.fetch(rarity.to_i).to_s, season_number.to_i, quantity.to_i ] }
    end
  end
end
