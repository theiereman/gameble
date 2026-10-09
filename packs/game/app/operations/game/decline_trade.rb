module Game
  class DeclineTrade < CloseTrade
    STATUS = "declined".freeze
    EVENT = TradeDeclined
    PARTY = :recipient_id

    private

    def current_terms_seen(trade, revision)
      current_terms(trade, revision)
    end
  end
end
