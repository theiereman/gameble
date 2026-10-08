module Game
  class IgnoreInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)

      transaction do
        invitation = token.is_a?(String) ? Invitation.pending.lock.find_by(token:, recipient_id: player.id) : nil
        step(invitation ? Success() : Failure(:not_found))
        invitation.update!(status: "ignored")
        invitation
      end
    end
  end
end
