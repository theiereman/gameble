module Game
  module TradeSuggestions
    module OpenTrades
      SQL = <<~SQL.squish.freeze
        SELECT DISTINCT CASE WHEN game_trades.proposer_id = :player_id THEN game_trades.recipient_id ELSE game_trades.proposer_id END,
               catalog_card_seasons.card_id
          FROM game_trade_items
          JOIN game_trades ON game_trades.id = game_trade_items.trade_id
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_trade_items.card_season_id
         WHERE game_trades.status = 'open' AND game_trades.expires_at > :now
           AND ((game_trades.proposer_id = :player_id AND game_trades.recipient_id IN (:friend_ids) AND game_trade_items.side = :proposer_side)
             OR (game_trades.recipient_id = :player_id AND game_trades.proposer_id IN (:friend_ids) AND game_trade_items.side = :recipient_side))
      SQL

      def self.offered_by(player, friend_ids, now) = pairs(player, friend_ids, now, proposer_side: "offer", recipient_side: "request")

      def self.requested_by(player, friend_ids, now) = pairs(player, friend_ids, now, proposer_side: "request", recipient_side: "offer")

      def self.pairs(player, friend_ids, now, **sides)
        sql = Trade.sanitize_sql_array([ SQL, { player_id: player.id, friend_ids:, now:, **sides } ])
        Trade.connection.select_rows(sql, "Game::TradeSuggestions::OpenTrades").to_set { |friend_id, card_id| [ friend_id.to_i, card_id.to_i ] }
      end

      private_class_method :pairs
    end
  end
end
