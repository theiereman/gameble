module Game
  class ExpireTrade < CloseTrade
    STATUS = "expired".freeze
    EVENT = TradeExpired
    PARTY = :proposer_id
    CLOSED_MEANWHILE = Dry::Monads::Failure(:trade_not_open)

    private

    def acting_player(player)
      require_account(player)
    end

    def closable(trade, now)
      trade.expired?(now) ? Success() : Failure(:trade_not_expired)
    end
  end
end
