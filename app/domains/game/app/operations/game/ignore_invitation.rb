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
