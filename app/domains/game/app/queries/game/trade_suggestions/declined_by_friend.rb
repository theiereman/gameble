module Game
  module TradeSuggestions
    module DeclinedByFriend
      SQL = <<~SQL.squish.freeze
        SELECT DISTINCT game_trades.recipient_id, catalog_card_seasons.card_id, game_trade_items.side
          FROM game_trade_items
          JOIN game_trades ON game_trades.id = game_trade_items.trade_id
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_trade_items.card_season_id
         WHERE game_trades.status = 'declined' AND game_trades.proposer_id = :player_id AND game_trades.recipient_id IN (:friend_ids)
      SQL

      Pairs = Data.define(:request, :offer)

      def self.call(player, friend_ids)
        sql = Trade.sanitize_sql_array([ SQL, { player_id: player.id, friend_ids: } ])
        pairs = { "request" => Set.new, "offer" => Set.new }
        Trade.connection.select_rows(sql, "Game::TradeSuggestions::DeclinedByFriend").each do |friend_id, card_id, side|
          pairs.fetch(side) << [ friend_id.to_i, card_id.to_i ]
        end
        Pairs.new(request: pairs["request"], offer: pairs["offer"])
      end
    end
  end
end
