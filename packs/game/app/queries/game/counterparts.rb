module Game
  # The players a player is tied to: the other party of each open trade, and
  # each friend or pending invitation's other side.
  #
  #   Game::Counterparts.call(player) # => { trades: [7], friends: [7, 9] }
  module Counterparts
    def self.call(player)
      { trades: trade_partners(player.id), friends: (friends(player.id) + invited(player.id)).uniq }
    end

    def self.trade_partners(id)
      Trade.in_progress.where(proposer_id: id).pluck(:recipient_id) + Trade.in_progress.where(recipient_id: id).pluck(:proposer_id)
    end

    def self.friends(id)
      Friendship.of(id).pluck(:low_player_id, :high_player_id).flatten - [ id ]
    end

    def self.invited(id)
      Invitation.pending.where(sender_id: id).pluck(:recipient_id) + Invitation.pending.where(recipient_id: id).pluck(:sender_id)
    end

    private_class_method :trade_partners, :friends, :invited
  end
end
