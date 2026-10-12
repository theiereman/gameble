module Game
  module OpenTradesByFriend
    def self.call(player, now: Time.current)
      return {} unless player

      open = Trade.in_progress.where(Trade.arel_table[:expires_at].gt(now))
      open.where(proposer_id: player.id).or(open.where(recipient_id: player.id))
        .pluck(:proposer_id, :recipient_id, :token)
        .to_h { |proposer_id, recipient_id, token| [ proposer_id == player.id ? recipient_id : proposer_id, token ] }
    end
  end
end
