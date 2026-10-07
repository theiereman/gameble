module Game
  class DeclineTrade < CloseTrade
    STATUS = "declined".freeze
    EVENT = TradeDeclined
    PARTY = :recipient_id
  end
end
