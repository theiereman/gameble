module Game
  module TierCounts
    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.rarity AS tier, SUM(game_holdings.quantity) AS copies
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
         AND catalog_card_seasons.rarity IS NOT NULL
       GROUP BY catalog_card_seasons.rarity
    SQL

    def self.call(player)
      counts = Catalog::Rarity::TIERS.keys.index_with(0)
      return counts if player.nil?

      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ SQL, { player_id: player.id } ]), "Game::TierCounts")
      rows.each { |tier, copies| counts[tier.to_i] = copies.to_i }
      counts
    end
  end
end
