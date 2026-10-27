module Game
  class DropFriendsAndTrades < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        step CancelOpenTrades.new.call(player:)
        Invitation.where(sender_id: player.id).or(Invitation.where(recipient_id: player.id)).delete_all
        Friendship.of(player.id).delete_all
        player
      end
    end
  end
end
