module Game
  module Counterparts
    def self.call(player)
      { trades: trade_partners(player.id), friends: (Friendship.other_ids(player.id) + invited(player.id)).uniq }
    end

    def self.trade_partners(id)
      Trade.in_progress.where(proposer_id: id).pluck(:recipient_id) + Trade.in_progress.where(recipient_id: id).pluck(:proposer_id)
    end

    def self.invited(id)
      Invitation.pending.where(sender_id: id).pluck(:recipient_id) + Invitation.pending.where(recipient_id: id).pluck(:sender_id)
    end

    private_class_method :trade_partners, :invited
  end
end
