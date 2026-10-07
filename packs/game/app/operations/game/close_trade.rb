module Game
  # What cancelling and declining share (AD-8): an open trade is closed by
  # the right party and the offer reserved on the proposer's holdings is
  # released, in one transaction with one event. Under the bank locks of both
  # players in ascending player id (AD-10), then the proposer's holdings in
  # ascending card-season. Not used directly: see Game::CancelTrade and
  # Game::DeclineTrade.
  #
  # Failure(:trade_not_found) for an unknown trade or one the player is not
  # part of, Failure(:not_allowed) for the other party, Failure(:trade_not_open)
  # for a trade already closed (nothing is written, nothing published).
  class CloseTrade < Operation
    def call(player:, trade_id:)
      player = step require_player(player)
      trade = step find_trade(player, trade_id)

      transaction do
        TradeLocks.players(trade.proposer_id, trade.recipient_id)
        trade = Trade.lock.find(trade.id)
        step still_open(trade)
        release(trade)
        trade.update!(status: self.class::STATUS, closed_at: Time.current)
        step publish(self.class::EVENT.new(data: { trade_id: trade.id, proposer_id: trade.proposer_id, recipient_id: trade.recipient_id }),
          stream_name: stream_name(trade.proposer_id))
        trade
      end
    end

    private

    def find_trade(player, trade_id)
      trade = Trade.find_by(id: trade_id)
      return Failure(:trade_not_found) unless trade && [ trade.proposer_id, trade.recipient_id ].include?(player.id)

      trade.public_send(self.class::PARTY) == player.id ? Success(trade) : Failure(:not_allowed)
    end

    def still_open(trade)
      trade.open? ? Success() : Failure(:trade_not_open)
    end

    def release(trade)
      offer = TradeItem.where(trade_id: trade.id, side: "offer").order(:card_season_id).pluck(:card_season_id, :quantity)
      holdings = TradeLocks.holdings(trade.proposer_id, offer.map(&:first))
      now = Time.current
      offer.each do |card_season_id, quantity|
        Holding.where(id: holdings.fetch(card_season_id).id).update_all([ "reserved = reserved - ?, updated_at = ?", quantity, now ])
      end
    end
  end
end
