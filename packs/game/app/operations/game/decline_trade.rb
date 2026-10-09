module Game
  class DeclineTrade < CloseTrade
    STATUS = "declined".freeze
    EVENT = TradeDeclined
    PARTY = :recipient_id

    private

    def current_terms_seen(trade, seen)
      same_terms(trade, seen)
    end
  end
end
