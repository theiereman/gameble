module Game
  class CloseTrade < Operation
    include TradeSteps

    def call(player:, trade_id:, revision: nil)
      player = step acting_player(player)
      trade = step find_trade(player, trade_id)
      step turn(trade, player, self.class::PARTY)

      transaction do
        trade = lock_trade(trade)
        step turn(trade, player, self.class::PARTY)
        step still_open(trade)
        step current_terms_seen(trade, revision)
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

    def current_terms_seen(trade, revision)
      revision ? current_terms(trade, revision) : Success()
    end

    def closable(_trade, _now)
      Success()
    end
  end
end
