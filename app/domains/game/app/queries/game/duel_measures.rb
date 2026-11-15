module Game
  # What the duel stats rank, for every rated card-season of a published season: its Steam reviews and whole percent, its
  # game's release date, its first discovery and the number of players holding it (Archives deposits are no holdings).
  module DuelMeasures
    Measure = Data.define(:card_season_id, :season_id, :rarity, :review_count, :rating, :release_date, :discovered_at, :holders)

    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.id, catalog_card_seasons.season_id, catalog_card_seasons.rarity, catalog_card_seasons.review_count,
             FLOOR(catalog_card_seasons.rating)::integer AS rating, catalog_cards.release_date,
             game_first_discoveries.discovered_at, holders.count AS holders
        FROM catalog_card_seasons
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id AND catalog_seasons.status = 'published'
        JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
        LEFT JOIN game_first_discoveries ON game_first_discoveries.card_season_id = catalog_card_seasons.id
        LEFT JOIN (
          SELECT card_season_id, COUNT(DISTINCT player_id) AS count
            FROM game_holdings
           WHERE quantity > 0
           GROUP BY card_season_id
        ) holders ON holders.card_season_id = catalog_card_seasons.id
       WHERE catalog_card_seasons.rarity IS NOT NULL
       ORDER BY catalog_card_seasons.id
    SQL

    def self.call
      DuelStat.connection.select_all(SQL, "Game::DuelMeasures").cast_values.map { Measure.new(*it) }
    end
  end
end
