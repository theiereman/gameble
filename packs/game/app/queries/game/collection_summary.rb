module Game
  # The header of a player's public profile (CAP-8): how many distinct cards
  # of the season they hold (card-seasons with copies left) and how many of
  # its sets they have completed (a set with members, every one held). One
  # query when the season is given; without it the published season is
  # looked up first. Zeros, without a query, for nil (a visitor) or no
  # season.
  #
  #   Game::CollectionSummary.call(player, season:) # => Summary(distinct_cards: 12, complete_sets: 1)
  module CollectionSummary
    Summary = Data.define(:distinct_cards, :complete_sets)
    NONE = Summary.new(distinct_cards: 0, complete_sets: 0)
    PUBLISHED = Object.new.freeze
    private_constant :PUBLISHED

    SQL = <<~SQL.squish.freeze
      SELECT
        (SELECT COUNT(*) FROM game_holdings
           JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
            AND catalog_card_seasons.season_id = :season_id) AS distinct_cards,
        (SELECT COUNT(*) FROM (
           SELECT catalog_set_memberships.set_id FROM catalog_set_memberships
             JOIN catalog_sets ON catalog_sets.id = catalog_set_memberships.set_id
             LEFT JOIN game_holdings ON game_holdings.card_season_id = catalog_set_memberships.card_season_id
               AND game_holdings.player_id = :player_id AND game_holdings.quantity > 0
            WHERE catalog_sets.season_id = :season_id
            GROUP BY catalog_set_memberships.set_id
           HAVING COUNT(*) = COUNT(game_holdings.id)) AS complete) AS complete_sets
    SQL

    def self.call(player, season: PUBLISHED)
      return NONE if player.nil?

      season = Catalog::PublishedSeason.call if season.equal?(PUBLISHED)
      return NONE if season.nil?

      row = Holding.connection.select_one(Holding.sanitize_sql_array([ SQL, { player_id: player.id, season_id: season.id } ]), "Game::CollectionSummary")
      Summary.new(distinct_cards: row["distinct_cards"].to_i, complete_sets: row["complete_sets"].to_i)
    end
  end
end
