module Game
  module OpenTradeCountsByFriend
    def self.call(player)
      return {} unless player

      Trade.in_progress.where(proposer_id: player.id).or(Trade.in_progress.where(recipient_id: player.id))
        .pluck(:proposer_id, :recipient_id)
        .map { |proposer_id, recipient_id| proposer_id == player.id ? recipient_id : proposer_id }
        .tally
    end
  end
end
