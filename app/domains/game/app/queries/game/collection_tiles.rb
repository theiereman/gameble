module Game
  module CollectionTiles
    SQL = <<~SQL.squish.freeze
      catalog_card_seasons.id IN (
        SELECT DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.id
          FROM catalog_card_seasons
          LEFT JOIN game_holdings ON game_holdings.card_season_id = catalog_card_seasons.id
           AND game_holdings.player_id = :player_id AND game_holdings.quantity > 0
         WHERE catalog_card_seasons.rarity IS NOT NULL
           AND (catalog_card_seasons.season_id = :season_id OR game_holdings.id IS NOT NULL)
         ORDER BY catalog_card_seasons.card_id, game_holdings.id IS NULL, #{HeldGames::EDITION_ORDER})
    SQL

    def self.call(player, season)
      return Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil) if player.nil?

      Catalog::CardSeason.where.not(rarity: nil).where(Holding.sanitize_sql_array([ SQL, { player_id: player.id, season_id: season.id } ]))
    end
  end
end
