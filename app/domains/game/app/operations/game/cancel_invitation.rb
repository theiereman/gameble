module Game
  class CancelInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)
      sent = step sent_by(player, token)

      transaction do
        TradeLocks.players(player.id, sent.recipient_id)
        invitation = Invitation.unanswered.lock.find_by(token:, sender_id: player.id)
        step(invitation ? Success() : Failure(:not_found))
        invitation.delete
        step publish(InvitationCancelled.new(data: { invitation_id: invitation.id, sender_id: player.id, recipient_id: invitation.recipient_id }),
          stream_name: stream_name(player.id))
        invitation
      end
    end

    private

    def sent_by(player, token)
      invitation = token.is_a?(String) ? Invitation.unanswered.find_by(token:, sender_id: player.id) : nil
      invitation ? Success(invitation) : Failure(:not_found)
    end
  end
end
