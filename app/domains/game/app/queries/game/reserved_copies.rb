module Game
  module ReservedCopies
    Reserved = Data.define(:on_sale, :in_trade)

    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.card_id, SUM(game_holdings.reserved) AS reserved,
             SUM(LEAST(COALESCE(listed.copies, 0), game_holdings.reserved)) AS on_sale
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        LEFT JOIN (%{listed}) listed ON listed.card_season_id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.reserved > 0
         AND catalog_card_seasons.card_id IN (:card_ids)
       GROUP BY catalog_card_seasons.card_id
    SQL

    DUPLICATES = <<~SQL.squish.freeze
      SELECT COALESCE(SUM(GREATEST(games.free - 1, 0)), 0)
        FROM (
          SELECT SUM(game_holdings.quantity - game_holdings.reserved) AS free
            FROM game_holdings
            JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
           WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
             AND catalog_card_seasons.rarity IS NOT NULL
           GROUP BY catalog_card_seasons.card_id
        ) games
    SQL

    def self.call(player, card_ids:)
      return {} if player.nil? || card_ids.empty?

      sql = Holding.sanitize_sql_array([ format(SQL, listed: listed(player).to_sql), { player_id: player.id, card_ids: card_ids.uniq } ])
      Holding.connection.select_rows(sql, "Game::ReservedCopies").to_h do |card_id, reserved, on_sale|
        on_sale = on_sale.to_i
        [ card_id.to_i, Reserved.new(on_sale:, in_trade: [ reserved.to_i - on_sale, 0 ].max) ]
      end
    end

    def self.duplicates(player)
      return 0 if player.nil?

      Holding.connection.select_value(Holding.sanitize_sql_array([ DUPLICATES, { player_id: player.id } ]), "Game::ReservedCopies.duplicates").to_i
    end

    def self.listed(player)
      Market::Listing.open_now.where(seller_id: player.id).group(:card_season_id).select(:card_season_id, Arel.sql("COUNT(*) AS copies"))
    end
    private_class_method :listed
  end
end
