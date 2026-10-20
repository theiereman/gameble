module Game
  # The header of a player's public profile: how many games they
  # hold, in any edition (Game::HeldGames), and how many of the season's
  # sets they have completed (a set with members, every member's game held
  # in any edition). One query when the season is given; without it the
  # published season is looked up first. Zeros, without a query, for nil (a
  # visitor) or no season.
  #
  #   Game::CollectionSummary.call(player, season:) # => Summary(distinct_cards: 12, complete_sets: 1)
  module CollectionSummary
    Summary = Data.define(:distinct_cards, :complete_sets)
    NONE = Summary.new(distinct_cards: 0, complete_sets: 0)
    PUBLISHED = Object.new.freeze
    private_constant :PUBLISHED

    SQL = <<~SQL.squish.freeze
      SELECT
        (SELECT COUNT(*) FROM (#{HeldGames::SQL}) AS held) AS distinct_cards,
        (SELECT COUNT(*) FROM (
           SELECT catalog_set_memberships.set_id FROM catalog_set_memberships
             JOIN catalog_sets ON catalog_sets.id = catalog_set_memberships.set_id
             JOIN catalog_card_seasons members ON members.id = catalog_set_memberships.card_season_id
             LEFT JOIN (#{HeldGames::SQL}) AS held ON held.card_id = members.card_id
            WHERE catalog_sets.season_id = :season_id
            GROUP BY catalog_set_memberships.set_id
           HAVING COUNT(*) = COUNT(held.card_id)) AS complete) AS complete_sets
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
