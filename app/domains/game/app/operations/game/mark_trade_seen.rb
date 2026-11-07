module Game
  # Notes that a player opened one of their trades, so its answer leaves their bell.
  class MarkTradeSeen < Operation
    def call(player:, trade_token:, now: Time.current)
      player = step require_player(player)

      transaction do
        trade = step own_trade(player, trade_token)
        step write(player, trade, now)
        step publish(TradeSeen.new(data: { player_id: player.id, trade_id: trade.id }), stream_name: stream_name(player.id))
        trade
      end
    end

    private

    def own_trade(player, token)
      trade = (Trade.find_by(token:) if token.is_a?(String))
      trade && [ trade.proposer_id, trade.recipient_id ].include?(player.id) ? Success(trade) : Failure(:trade_not_found)
    end

    def write(player, trade, now)
      TradeView.upsert({ player_id: player.id, trade_id: trade.id, seen_at: now }, unique_by: %i[player_id trade_id],
        on_duplicate: Arel.sql("seen_at = GREATEST(game_trade_views.seen_at, EXCLUDED.seen_at), updated_at = EXCLUDED.updated_at"))
      Success()
    end
  end
end
