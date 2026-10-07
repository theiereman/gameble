module Game
  # Closes an open trade 7 days after its last send or counter (AD-8): it
  # closes as `expired`, the proposer's offer is released and
  # Game::TradeExpired is published. Run by Game::ExpireTradesJob, one trade
  # per transaction, for the trade's proposer (AD-14). The clock acts, not
  # the player: a banned proposer's trade expires too, so their reservations
  # do not outlive it. See Game::CloseTrade for the order of locks and the
  # other failures; a trade not yet past its expiry fails :trade_not_expired.
  #
  #   Game::ExpireTrade.new.call(player: proposer, trade_id:)
  #   # => Success(trade) | Failure(:player_required) | Failure(:trade_not_found)
  #   #    | Failure(:not_allowed) | Failure(:trade_not_open) | Failure(:trade_not_expired)
  class ExpireTrade < CloseTrade
    STATUS = "expired".freeze
    EVENT = TradeExpired
    PARTY = :proposer_id

    private

    def acting_player(player)
      player.is_a?(Accounts::Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end

    def closable(trade, now)
      trade.expired?(now) ? Success() : Failure(:trade_not_expired)
    end
  end
end
