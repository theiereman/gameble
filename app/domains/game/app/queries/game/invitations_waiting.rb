module Game
  module InvitationsWaiting
    def self.call(player)
      return 0 unless player

      Invitation.pending
        .where(recipient_id: player.id)
        .where(sender_id: Accounts::Player.in_good_standing.select(:id))
        .count
    end
  end
end
