module Game
  # The games a player holds, whatever the season of their copies: per card,
  # the best rarity among the card-seasons held with copies left, and the
  # latest gain among them (`gained_at`, NULL when none was ever timed).
  #
  #   Game::HeldGames.call(player_id) # => { card_id => rarity, … }
  #   Game::HeldGames.call(player_id, card_ids: [ … ]) # those cards only
  #
  # `count`: how many games a player holds; `by_rarity`: how many at each
  # best rarity, every tier of Catalog::Rarity::TIERS a key. One query each;
  # 0 and zeros, without a query, for nil (a visitor).
  #
  #   Game::HeldGames.count(player) # => 17
  #   Game::HeldGames.by_rarity(player) # => { 1 => 12, 2 => 4, 3 => 1, 4 => 0, 5 => 0 }
  #
  # `editions`: per game asked about that the player holds, the edition it
  # shows (EDITION_ORDER), the copies over every edition, whether any is new
  # (as in CollectionSlots), how many editions are held and the latest gain;
  # one query, nothing for nil.
  #
  #   Game::HeldGames.editions(player, card_ids: [ … ], season:)
  #   # => { card_id => Edition(card_season_id: 7, copies: 3, new: true, editions: 2, gained_at: Time) }
  module HeldGames
    Edition = Data.define(:card_season_id, :copies, :new, :editions, :gained_at)

    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.card_id, MAX(catalog_card_seasons.rarity) AS rarity,
             MAX(game_holdings.last_gained_at) AS gained_at
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
       GROUP BY catalog_card_seasons.card_id
    SQL

    EDITION_ORDER = <<~SQL.squish.freeze
      catalog_card_seasons.rarity DESC NULLS LAST, (catalog_card_seasons.season_id = :season_id) DESC, catalog_card_seasons.id DESC
    SQL

    def self.call(player_id, card_ids: nil)
      return {} if card_ids&.empty?

      sql = "SELECT held.card_id, held.rarity FROM (#{SQL}) AS held"
      sql += " WHERE held.card_id IN (:card_ids)" if card_ids
      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ sql, { player_id:, card_ids: } ]), "Game::HeldGames")
      rows.to_h { |card_id, rarity| [ card_id.to_i, rarity&.to_i ] }
    end

    def self.count(player)
      return 0 if player.nil?

      sql = Holding.sanitize_sql_array([ "SELECT COUNT(*) FROM (#{SQL}) AS held", { player_id: player.id } ])
      Holding.connection.select_value(sql, "Game::HeldGames.count").to_i
    end

    def self.by_rarity(player)
      counts = Catalog::Rarity::TIERS.keys.index_with(0)
      return counts if player.nil?

      sql = Holding.sanitize_sql_array([
        "SELECT held.rarity, COUNT(*) FROM (#{SQL}) AS held WHERE held.rarity IS NOT NULL GROUP BY held.rarity", { player_id: player.id }
      ])
      Holding.connection.select_rows(sql, "Game::HeldGames.by_rarity").each { |tier, games| counts[tier.to_i] = games.to_i }
      counts
    end

    EDITIONS = <<~SQL.squish.freeze
      SELECT DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.card_id, game_holdings.card_season_id,
             SUM(game_holdings.quantity) OVER games AS copies,
             BOOL_OR(#{CollectionSlots::NEW}) OVER games AS new,
             COUNT(*) OVER games AS editions,
             MAX(game_holdings.last_gained_at) OVER games AS gained_at
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        LEFT JOIN game_player_states ON game_player_states.player_id = game_holdings.player_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
         AND catalog_card_seasons.card_id IN (:card_ids)
      WINDOW games AS (PARTITION BY catalog_card_seasons.card_id)
       ORDER BY catalog_card_seasons.card_id, #{EDITION_ORDER}
    SQL

    def self.editions(player, card_ids:, season:)
      return {} if player.nil? || card_ids.empty?

      sql = Holding.sanitize_sql_array([ EDITIONS, { player_id: player.id, card_ids: card_ids.uniq, season_id: season.id } ])
      Holding.connection.select_all(sql, "Game::HeldGames.editions").cast_values.to_h do |card_id, card_season_id, copies, fresh, editions, gained_at|
        [ card_id, Edition.new(card_season_id:, copies: copies.to_i, new: fresh, editions: editions.to_i, gained_at:) ]
      end
    end
  end
end
