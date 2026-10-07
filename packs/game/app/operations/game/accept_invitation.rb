module Game
  class AcceptInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)

      transaction do
        invitation = step pending_for(player, token)
        low, high = [ invitation.sender_id, invitation.recipient_id ].minmax
        Friendship.insert({ low_player_id: low, high_player_id: high }, unique_by: %i[low_player_id high_player_id])
        invitation.update!(status: "accepted")
        step publish(InvitationAccepted.new(data: { invitation_id: invitation.id, sender_id: invitation.sender_id, recipient_id: player.id }),
          stream_name: stream_name(player.id))
        invitation
      end
    end

    private

    def pending_for(player, token)
      invitation = token.is_a?(String) ? Invitation.pending.lock.find_by(token:, recipient_id: player.id) : nil
      sender = invitation && Accounts::PlayerById.call(invitation.sender_id)
      sender && !sender.removed? ? Success(invitation) : Failure(:not_found)
    end
  end
end
