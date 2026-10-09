module Game
  module OpenTradeCount
    def self.call(player)
      return 0 unless player

      Trade.in_progress.where(proposer_id: player.id).or(Trade.in_progress.where(recipient_id: player.id)).count
    end
  end
end
