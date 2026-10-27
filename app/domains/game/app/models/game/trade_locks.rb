module Game
  module TradeLocks
    def self.players(*player_ids)
      player_ids.uniq.sort.each { |player_id| BankLock.acquire(player_id) }
    end

    def self.holdings(player_id, card_season_ids)
      Holding.where(player_id:, card_season_id: card_season_ids).order(:card_season_id).lock.index_by(&:card_season_id)
    end
  end
end
