module Game
  # The proposer cancels their open trade (AD-8): it closes as `cancelled`,
  # the offer is released and Game::TradeCancelled is published. See
  # Game::CloseTrade for the order of locks and the failures.
  #
  #   Game::CancelTrade.new.call(player:, trade_id:)
  #   # => Success(trade) | Failure(:player_required) | Failure(:trade_not_found)
  #   #    | Failure(:not_allowed) | Failure(:trade_not_open)
  class CancelTrade < CloseTrade
    STATUS = "cancelled".freeze
    EVENT = TradeCancelled
    PARTY = :proposer_id
  end
end
