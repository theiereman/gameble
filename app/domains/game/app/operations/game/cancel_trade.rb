module Game
  class CancelTrade < CloseTrade
    STATUS = "cancelled".freeze
    EVENT = TradeCancelled
    PARTY = :proposer_id
  end
end
