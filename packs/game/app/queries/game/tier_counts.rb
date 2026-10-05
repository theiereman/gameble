module Game
  # The top bar's rarity counter (DESIGN.md, Rarity counter): the copies a
  # player holds in each rarity tier of the published season (the
  # highest-numbered published one, looked up in the same query). Every tier
  # of Catalog::Rarity::TIERS is a key; zeros, without a query, for nil (a
  # visitor), and zeros when no season is published.
  #
  #   Game::TierCounts.call(player) # => { 1 => 12, 2 => 4, 3 => 1, 4 => 0, 5 => 0 }
  module TierCounts
    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.rarity AS tier, SUM(game_holdings.quantity) AS copies
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
         AND catalog_card_seasons.rarity IS NOT NULL
         AND catalog_card_seasons.season_id = (
           SELECT catalog_seasons.id FROM catalog_seasons
            WHERE catalog_seasons.status = 'published'
            ORDER BY catalog_seasons.number DESC LIMIT 1)
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
