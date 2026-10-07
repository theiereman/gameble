module Game
  # What cancelling, declining and expiring share (AD-8): an open trade is
  # closed by the right party and the offer reserved on the proposer's
  # holdings is released, in one transaction with one event. Under the bank
  # locks of both players in ascending player id (AD-10), then the trade
  # row, then the proposer's holdings in ascending card-season. Not used
  # directly: see Game::CancelTrade, Game::DeclineTrade and Game::ExpireTrade.
  #
  # Failure(:trade_not_found) for an unknown trade or one the player is not
  # part of, Failure(:not_allowed) for the other party (checked again under
  # the lock, since a counter-proposal swaps the parties' roles),
  # Failure(:trade_not_open) for a trade already closed (nothing is written,
  # nothing published).
  class CloseTrade < Operation
    include TradeSteps

    def call(player:, trade_id:)
      player = step acting_player(player)
      trade = step find_trade(player, trade_id)
      step turn(trade, player, self.class::PARTY)

      transaction do
        TradeLocks.players(trade.proposer_id, trade.recipient_id)
        trade = Trade.lock.find(trade.id)
        step turn(trade, player, self.class::PARTY)
        step still_open(trade)
        now = Time.current
        step closable(trade, now)
        offer = side_of(trade, "offer")
        release(offer, TradeLocks.holdings(trade.proposer_id, offer.keys), now)
        trade.update!(status: self.class::STATUS, closed_at: now)
        step publish(self.class::EVENT.new(data: { trade_id: trade.id, proposer_id: trade.proposer_id, recipient_id: trade.recipient_id }),
          stream_name: stream_name(trade.proposer_id))
        trade
      end
    end

    private

    def acting_player(player)
      require_player(player)
    end

    # Whether the trade may close now, beyond being open.
    def closable(_trade, _now)
      Success()
    end
  end
end
