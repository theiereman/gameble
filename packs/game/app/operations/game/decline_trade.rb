module Game
  # The friend declines an open trade (AD-8): it closes as `declined`, the
  # proposer's offer is released and Game::TradeDeclined is published. See
  # Game::CloseTrade for the order of locks and the failures.
  #
  #   Game::DeclineTrade.new.call(player:, trade_id:)
  #   # => Success(trade) | Failure(:player_required) | Failure(:trade_not_found)
  #   #    | Failure(:not_allowed) | Failure(:trade_not_open)
  class DeclineTrade < CloseTrade
    STATUS = "declined".freeze
    EVENT = TradeDeclined
    PARTY = :recipient_id
  end
end
