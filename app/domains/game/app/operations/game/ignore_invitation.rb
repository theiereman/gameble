module Game
  class IgnoreInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)
      received = step received_by(player, token)

      transaction do
        TradeLocks.players(received.sender_id, player.id)
        invitation = Invitation.pending.lock.find_by(token:, recipient_id: player.id)
        step(invitation ? Success() : Failure(:not_found))
        invitation.update!(status: "ignored")
        step publish(InvitationIgnored.new(data: { invitation_id: invitation.id, sender_id: invitation.sender_id, recipient_id: player.id }),
          stream_name: stream_name(player.id))
        invitation
      end
    end

    private

    def received_by(player, token)
      invitation = token.is_a?(String) ? Invitation.pending.find_by(token:, recipient_id: player.id) : nil
      invitation ? Success(invitation) : Failure(:not_found)
    end
  end
end
