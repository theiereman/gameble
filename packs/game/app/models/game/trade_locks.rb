module Game
  # The lock order of the trade operations (AD-6, AD-10): each player's bank
  # lock in ascending player id, then the holdings in ascending card-season
  # (one player's rows at a time, lower player first).
  module TradeLocks
    # Must run inside a transaction.
    def self.players(*player_ids)
      player_ids.uniq.sort.each { |player_id| BankLock.acquire(player_id) }
    end

    # Locks and returns a player's holdings of the given card-seasons, by
    # card-season, in ascending order. Must run inside a transaction.
    def self.holdings(player_id, card_season_ids)
      Holding.where(player_id:, card_season_id: card_season_ids).order(:card_season_id).lock.index_by(&:card_season_id)
    end
  end
end
